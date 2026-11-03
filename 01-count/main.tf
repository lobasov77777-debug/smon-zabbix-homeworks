terraform {
  required_version = ">= 1.8.4"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }
}

variable "folder_id" { type = string }

provider "yandex" {
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  zones = ["ru-central1-a", "ru-central1-d"]
}

resource "yandex_vpc_network" "web" {
  name = "netology-sflt4-1"
}

resource "yandex_vpc_subnet" "web" {
  count          = length(local.zones)
  name           = "netology-sflt4-1-${count.index + 1}"
  zone           = local.zones[count.index]
  network_id     = yandex_vpc_network.web.id
  v4_cidr_blocks = [cidrsubnet("10.44.0.0/16", 8, count.index)]
}

resource "yandex_vpc_security_group" "web" {
  name       = "netology-sflt4-1-web"
  network_id = yandex_vpc_network.web.id
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "TCP"
    port              = 80
    predefined_target = "loadbalancer_healthchecks"
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_compute_instance" "web" {
  count       = 2
  name        = "netology-sflt4-1-web-${count.index + 1}"
  zone        = local.zones[count.index]
  platform_id = "standard-v3"
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.web[count.index].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.web.id]
  }
  metadata = {
    user-data = file("${path.module}/cloud-init.yaml")
  }
}

resource "yandex_lb_target_group" "web" {
  name = "netology-sflt4-1-web"
  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}


resource "yandex_lb_network_load_balancer" "web" {
  name = "netology-sflt4-1"
  type = "external"
  listener {
    name        = "http"
    port        = 80
    target_port = 80
    protocol    = "tcp"
    external_address_spec { ip_version = "ipv4" }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.web.id
    healthcheck {
      name                = "nginx"
      interval            = 5
      timeout             = 2
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "balancer_ip" {
  value = one(flatten([for listener in yandex_lb_network_load_balancer.web.listener : [for address in listener.external_address_spec : address.address]]))
}
