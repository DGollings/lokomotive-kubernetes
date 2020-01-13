# Get some public IPs to use for our load balancer
resource "packet_reserved_ip_block" "load_balancer_ips" {
  project_id = var.project_id
  facility   = var.facility
  quantity   = 2
}

# Deploy MetalLB
resource "null_resource" "setup_metallb" {
  connection {
    type    = "ssh"
    host    = packet_device.controllers[0].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "file" {
    content     = data.template_file.metallb_config.rendered
    destination = "/tmp/metallb-config.yaml"
  }

  provisioner "file" {
    content     = module.bootkube.kubeconfig-admin
    destination = "/tmp/kubeconfig"
  }
  provisioner "remote-exec" {
    inline = [
      # TODO get version from a var
      # TODO figure out how to support ARM
      "curl -L  https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl -o /tmp/kubectl",
      "chmod +x /tmp/kubectl",
      "/tmp/kubectl --kubeconfig=/tmp/kubeconfig apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml",
      "/tmp/kubectl --kubeconfig=/tmp/kubeconfig apply -f /tmp/metallb-config.yaml", # CHECKED
    ]
  }
}

data "template_file" "metallb_config" {
  template = file("${path.module}/templates/metallb-config.yaml.tpl")

  vars = {
    cidr = packet_reserved_ip_block.load_balancer_ips.cidr_notation
  }
}
