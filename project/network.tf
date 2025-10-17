#---------- Создаем облачную сеть
resource "yandex_vpc_network" "diplom" {
  name = "diplom-${var.flow}"
}

#---------- Публичная подсеть (для bastion, zabbix, kibana)
resource "yandex_vpc_subnet" "public_a" {
  name           = "public-${var.flow}-ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = ["10.0.10.0/24"]
}

#---------- Приватная подсеть zone A (для web1)
resource "yandex_vpc_subnet" "diplom_a" {
  name           = "private-${var.flow}-ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = ["10.0.1.0/28"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#---------- Приватная подсеть zone B (для web2, elasticsearch)
resource "yandex_vpc_subnet" "diplom_b" {
  name           = "private-${var.flow}-ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = ["10.0.2.0/28"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#---------- NAT-шлюз
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "gateway-${var.flow}"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "route-table-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#---------- Security Group: bastion
resource "yandex_vpc_security_group" "bastion" {
  name       = "bastion-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  ingress {
    description    = "SSH from internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    description    = "Zabbix agent from Zabbix server"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------- Security Group: kibana
resource "yandex_vpc_security_group" "kibana" {
  name       = "kibana-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  # Доступ из интернета для проверяющего
  ingress {
    description    = "Kibana UI from internet (for reviewer)"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Доступ из bastion (для Ansible)
  ingress {
    description    = "Kibana UI from bastion subnet"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.10.0/24"]
    port           = 5601
  }

  ingress {
    description    = "Zabbix agent from Zabbix server"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "SSH from bastion subnet (for Ansible)"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.10.0/24"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------- Security Group: zabbix
resource "yandex_vpc_security_group" "zabbix" {
  name       = "zabbix-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  # Доступ из интернета для проверяющего
  ingress {
    description    = "Zabbix Web UI from internet (for reviewer)"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Доступ из bastion (для Ansible)
  ingress {
    description    = "Zabbix Web UI from bastion subnet"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.10.0/24"]
    port           = 80
  }

  ingress {
    description    = "Zabbix agent communication (from internal)"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.0.0/8"]
    port           = 10051
  }

  ingress {
    description    = "Zabbix agent from Zabbix server"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "SSH from bastion subnet (for Ansible)"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.10.0/24"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------- Security Group: веб-серверы
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  ingress {
    description       = "HTTP from ALB and health checks"
    protocol          = "TCP"
    port              = 80
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description    = "HTTP from bastion subnet (for testing)"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "Zabbix agent from Zabbix server"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "SSH from bastion subnet (for Ansible)"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------- Security Group: elasticsearch
resource "yandex_vpc_security_group" "elasticsearch" {
  name       = "elasticsearch-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  ingress {
    description    = "Filebeat from web servers"
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["10.0.1.0/28", "10.0.2.0/28"]
  }

  ingress {
    description    = "Kibana"
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "Zabbix agent from Zabbix server"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["10.0.10.0/24"]
  }

  ingress {
    description    = "SSH from bastion subnet (for Ansible)"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.0.10.0/24"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------- Security Group: публичный балансировщик
resource "yandex_vpc_security_group" "public_lb" {
  name       = "public-lb-sg-${var.flow}"
  network_id = yandex_vpc_network.diplom.id

  ingress {
    description       = "Health checks from Yandex"
    protocol          = "ANY"
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description    = "HTTP from internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
