data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

#---------- Bastion host
resource "yandex_compute_instance" "vm-bastion" {
  name        = "vm-bastion"
  hostname    = "vm-bastion"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-bastion.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }
}

#---------- Web server 1
resource "yandex_compute_instance" "vm-web1" {
  name        = "vm-web1"
  hostname    = "vm-web1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-default.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
}

#---------- Web server 2
resource "yandex_compute_instance" "vm-web2" {
  name        = "vm-web2"
  hostname    = "vm-web2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-default.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
}

#---------- Zabbix
resource "yandex_compute_instance" "vm-zabbix" {
  name        = "vm-zabbix"
  hostname    = "vm-zabbix"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-default.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.zabbix.id]
  }
}

#---------- Elasticsearch
resource "yandex_compute_instance" "vm-elastic" {
  name        = "vm-elastic"
  hostname    = "vm-elastic"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 4
    memory        = 4
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-default.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.elasticsearch.id]
  }
}

#---------- Kibana
resource "yandex_compute_instance" "vm-kibana" {
  name        = "vm-kibana"
  hostname    = "vm-kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = var.cfg.cores
    memory        = var.cfg.memory
    core_fraction = var.cfg.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = var.cfg.storage
    }
  }

  metadata = {
    user-data = file("./cloud-init-default.yaml")
    serial-port-enable = 1
  }

#  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana.id]
  }
}

#---------- Inventory для Ansible (FQDN!)
resource "local_file" "inventory" {
  content = <<-EOF
[bastion]
vm-bastion.ru-central1.internal

[webservers]
vm-web1.ru-central1.internal
vm-web2.ru-central1.internal

[zabbix]
vm-zabbix.ru-central1.internal

[elastic]
vm-elastic.ru-central1.internal

[kibana]
vm-kibana.ru-central1.internal
EOF

  filename = "./hosts.ini"
}

#---------- Snapshot schedule
resource "yandex_compute_snapshot_schedule" "diplom" {
  name = "diplom-snap-${var.flow}"

  schedule_policy {
    expression = "0 22 ? * *"  # ежедневно в 22:00 UTC
  }

  snapshot_count = 7

  snapshot_spec {
    description = "Daily snapshot for diplom"
  }

  disk_ids = [
    yandex_compute_instance.vm-bastion.boot_disk.0.disk_id,
    yandex_compute_instance.vm-web1.boot_disk.0.disk_id,
    yandex_compute_instance.vm-web2.boot_disk.0.disk_id,
    yandex_compute_instance.vm-elastic.boot_disk.0.disk_id,
    yandex_compute_instance.vm-kibana.boot_disk.0.disk_id,
    yandex_compute_instance.vm-zabbix.boot_disk.0.disk_id,
  ]
}

#---------- ALB
resource "yandex_alb_target_group" "target_group" {
  name = "target-group-${var.flow}"

  target {
    subnet_id  = yandex_vpc_subnet.diplom_a.id
    ip_address = yandex_compute_instance.vm-web1.network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.diplom_b.id
    ip_address = yandex_compute_instance.vm-web2.network_interface.0.ip_address
  }
}

resource "yandex_alb_backend_group" "backend_group" {
  name = "backend-group-${var.flow}"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.target_group.id]
    healthcheck {
      timeout             = "10s"
      interval            = "2s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "http_router" {
  name = "http-router-${var.flow}"
}

resource "yandex_alb_virtual_host" "virtual_host" {
  name           = "virtual-host-${var.flow}"
  http_router_id = yandex_alb_http_router.http_router.id

  route {
    name = "main-route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.backend_group.id
        timeout          = "5s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "diplom_lb" {
  name        = "diplom-lb-${var.flow}"
  network_id  = yandex_vpc_network.diplom.id
  security_group_ids = [yandex_vpc_security_group.public_lb.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http_router.id
      }
    }
  }
}
