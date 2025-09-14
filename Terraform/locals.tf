data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
}
