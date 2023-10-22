terraform {
  required_providers {
    cloudbit = {
      source = "cloudbit-ch/cloudbit"
    }
  }
}

variable "cloudbit_api_token" {
  sensitive = true
}

provider "cloudbit" {
  token = var.cloudbit_api_token
}

data "cloudbit_product" "server_type" {
  name = "b1.8x32"
}

data "cloudbit_compute_image" "debian" {
  key = "linux-debian-12"
}

data "cloudbit_compute_network" "default" {
  name = "Default Network"
}

data "cloudbit_compute_key_pair" "key_pair" {
  name = "shared@thecodinglab.dev"
}

resource "cloudbit_compute_elastic_ip" "public_ip" {
  location_id = data.cloudbit_compute_network.default.location_id
}

resource "cloudbit_compute_server" "server" {
  name = "minecraft-server"

  location_id = data.cloudbit_compute_network.default.location_id
  image_id = data.cloudbit_compute_image.debian.id
  product_id = data.cloudbit_product.server_type.id
  network_id = data.cloudbit_compute_network.default.id
  key_pair_id = data.cloudbit_compute_key_pair.key_pair.id
}

data "cloudbit_compute_network_interface" "iface" {
  depends_on = [
    cloudbit_compute_server.server
  ]

  server_id = cloudbit_compute_server.server.id
}

resource "cloudbit_compute_elastic_ip_server_attachment" "server_public_ip" {
  depends_on = [
    cloudbit_compute_server.server,
    cloudbit_compute_elastic_ip.public_ip
  ]

  server_id = cloudbit_compute_server.server.id
  elastic_ip_id = cloudbit_compute_elastic_ip.public_ip.id
  network_interface_id = data.cloudbit_compute_network_interface.iface.id
}

resource "local_file" "ansible_inventory" {
  depends_on = [
    cloudbit_compute_elastic_ip.public_ip
  ]

  content = templatefile("inventory.ini.tmpl", {
    public_ip = cloudbit_compute_elastic_ip.public_ip.public_ip
  })

  filename = "inventory.ini"
}
