# Get some public IPs to use for our load balancer
# resource "packet_reserved_ip_block" "load_balancer_ips" {
#   project_id = var.project_id
#   facility   = var.facility
#   quantity   = 2
# }

resource "null_resource" "temporary-kubeconfig" {
  count = var.worker_count

  connection {
    type    = "ssh"
    host    = packet_device.nodes[count.index].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  triggers = {
    manifest_sha1 = "${sha1("${var.kubeconfig-admin}")}"
  }

  provisioner "file" {
    content     = var.kubeconfig-admin
    destination = "/tmp/kubeconfig"
  }
}

# Add Calico configs to make MetalLB work
resource "null_resource" "install_calicoctl" {
  count = var.worker_count

  connection {
    type    = "ssh"
    host    = packet_device.nodes[count.index].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -L  https://github.com/projectcalico/calicoctl/releases/download/v3.5.8/calicoctl -o /tmp/calicoctl",
      "chmod +x /tmp/calicoctl",
    ]
  }
}

# We need to get the private IPv4 Gateway of each worker
data "external" "private_ipv4_gateway" {
  count   = var.worker_count
  program = ["${path.module}/scripts/gateway.sh"]

  query = {
    host = "${element(packet_device.nodes.*.access_public_ipv4, count.index)}"
  }
}

# Add each node's peer to as a Calico bgppeer
resource "null_resource" "calico_node_peers" {
  count = var.worker_count

  connection {
    type    = "ssh"
    host    = packet_device.nodes[count.index].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "file" {
    # TODO rename scripts folder
    source      = "${path.module}/scripts/calico-bgppeer.sh"
    destination = "/tmp/bgppeer-${count.index}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bgppeer-${count.index}.sh",
      "/tmp/bgppeer-${count.index}.sh ${element(packet_device.nodes.*.hostname, count.index)} ${element(data.external.private_ipv4_gateway.*.result.peer_ip, count.index)}",
    ]
  }
  depends_on = [null_resource.install_calicoctl, null_resource.temporary-kubeconfig]
}
