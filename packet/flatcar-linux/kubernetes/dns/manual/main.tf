variable "entries" {
  type = list(
    object({
      name    = string
      type    = string
      ttl     = number
      records = list(string)
    })
  )
}

resource "local_file" "dns-entries" {
  content     = jsonencode(var.entries)
  filename = "./dns-entries.txt"
}
