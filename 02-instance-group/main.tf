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
  name = "netology-sflt4-2"
}

resource "yandex_vpc_subnet" "web" {
  count          = length(local.zones)
  name           = "netology-sflt4-2-${count.index + 1}"
  zone           = local.zones[count.index]
  network_id     = yandex_vpc_network.web.id
  v4_cidr_blocks = [cidrsubnet("10.44.0.0/16", 8, count.index)]
}

resource "yandex_vpc_security_group" "web" {
  name       = "netology-sflt4-2-web"
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

variable "instance_group_service_account_id" { type = string }

resource "yandex_compute_instance_group" "web" {
  name               = "netology-sflt4-2-web"
  service_account_id = var.instance_group_service_account_id
  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 20
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.ubuntu.id
        size     = 10
        type     = "network-hdd"
      }
    }
    network_interface {
      network_id         = yandex_vpc_network.web.id
      subnet_ids         = yandex_vpc_subnet.web[*].id
      nat                = true
      security_group_ids = [yandex_vpc_security_group.web.id]
    }
    metadata = {
      user-data = file("${path.module}/cloud-init.yaml")
    }
  }
  scale_policy {
    fixed_scale { size = 2 }
  }
  allocation_policy { zones = local.zones }
  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }
  load_balancer {
    target_group_name = "netology-sflt4-2-web"
  }
}

resource "yandex_lb_network_load_balancer" "web" {
  name = "netology-sflt4-2"
  type = "external"
  listener {
    name        = "http"
    port        = 80
    target_port = 80
    protocol    = "tcp"
    external_address_spec { ip_version = "ipv4" }
  }
  attached_target_group {
    target_group_id = yandex_compute_instance_group.web.load_balancer[0].target_group_id
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
