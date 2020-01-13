# Get some public IPs to use for our load balancer
# resource "packet_reserved_ip_block" "load_balancer_ips" {
#   project_id = var.project_id
#   facility   = var.facility
#   quantity   = 2
# }

# Enable BGP on each worker node
resource "packet_bgp_session" "kube_bgp" {
  count          = var.worker_count
  device_id      = packet_device.nodes.*.id[count.index]
  address_family = "ipv4"
}

# # Add Calico configs to make MetalLB work
# resource "null_resource" "setup_calico_metallb" {
#   connection {
#     type    = "ssh"
#     host    = packet_device.controllers[0].access_public_ipv4
#     user    = "core"
#     timeout = "15m"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "curl -L  https://github.com/projectcalico/calicoctl/releases/download/v3.5.8/calicoctl -o /tmp/calicoctl",
#       "chmod +x /tmp/calicoctl",
#     ]
#   }

#   provisioner "file" {
#     content     = data.template_file.calico_metallb.rendered
#     destination = "/tmp/calico/metallb.yaml"
#   }

#   provisioner "file" {
#     content     = data.module.bootkube.kubeconfig-admin.rendered
#     destination = "/tmp/kubeconfig"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "DATASTORE_TYPE=kubernetes KUBECONFIG=/tmp/kubeconfig /tmp/calico/calicoctl create -f /tmp/calico/metallb.yaml",
#     ]
#   }
# }

# # Deploy MetalLB
# resource "null_resource" "setup_metallb" {
#   connection {
#     type    = "ssh"
#     host    = packet_device.controllers[0].access_public_ipv4
#     user    = "core"
#     timeout = "15m"
#   }

#   provisioner "file" {
#     content     = data.template_file.metallb_config.rendered
#     destination = "/tmp/metallb-config.yaml"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       # TODO get version from a var
#       # TODO figure out how to support ARM
#       "curl -L  https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl -o /tmp/kubectl",
#       "chmod +x /tmp/kubectl",
#       "/tmp/kubectl --kubeconfig=/tmp/kubeconfig apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml",
#       "/tmp/kubectl --kubeconfig=/tmp/kubeconfig apply -f /tmp/metallb-config.yaml",
#     ]
#   }

#   depends_on = [null_resource.setup_calico_metallb]
# }

# Add each node's peer to as a Calico bgppeer
resource "null_resource" "calico_node_peers" {
  count = var.worker_count

  connection {
    type    = "ssh"
    host    = packet_device.controllers[count.index].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "file" {
    # TODO rename scripts folder
    source      = "${path.module}/scripts/calico-bgppeer.sh"
    destination = "/tmp/calico/bgppeer-${count.index}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/calico/bgppeer-${count.index}.sh",
      "/tmp/calico/bgppeer-${count.index}.sh ${element(packet_device.nodes.*.hostname, count.index)} ${element(data.external.private_ipv4_gateway.*.result.peer_ip, count.index)}",
    ]
  }

  depends_on = [null_resource.setup_calico_metallb]
}

# data "template_file" "calico_metallb" {
#   template = file("${path.module}/templates/calico-metallb.yaml.tpl")

#   vars = {
#     cidr = packet_reserved_ip_block.load_balancer_ips.cidr_notation
#   }
# }

# data "template_file" "metallb_config" {
#   template = file("${path.module}/templates/metallb-config.yaml.tpl")

#   vars = {
#     cidr = packet_reserved_ip_block.load_balancer_ips.cidr_notation
#   }
# }
