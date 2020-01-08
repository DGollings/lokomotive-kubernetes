module "dns-entries" {
  source = "./dns/manual/"

  entries = concat(
    # etcd
    [
      for device in packet_device.controllers:
      {
        name    = format("%s-etcd%d.%s.", var.cluster_name, index(packet_device.controllers, device), var.dns_zone),
        type    = "A",
        ttl     = 300,
        records = [device.access_private_ipv4],
      }
    ],
    [
      # apiserver public
      {
        name    = format("%s.%s.", var.cluster_name, var.dns_zone),
        type    = "A",
        ttl     = 300,
        records = packet_device.controllers.*.access_public_ipv4,
      },
      # apiserver private
      {
        name    = format("%s-private.%s.", var.cluster_name, var.dns_zone),
        type    = "A",
        ttl     = 300,
        records = packet_device.controllers.*.access_private_ipv4,
      },
    ]
  )
}
