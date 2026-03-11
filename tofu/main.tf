provider "docker" {}

locals {
  kube_context            = "k3d-${var.k3d_cluster_name}"
  postgres_host           = "localhost"
  postgres_db_name        = "postgrest"
  postgres_container_name = "postgres-infra-takehome"
}

resource "terraform_data" "k3d_cluster" {
  input = {
    name  = var.k3d_cluster_name
    image = "rancher/k3s:${var.k3s_version}"
  }

  provisioner "local-exec" {
    command = "k3d cluster create ${self.input.name} --image ${self.input.image} --servers 1 --agents 0 -p '8080:80@loadbalancer'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.input.name}"
  }
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_volume" "postgres_data" {
  name = "postgres-infra-takehome-data"
}

resource "docker_container" "postgres" {
  name  = local.postgres_container_name
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=app",
  ]

  ports {
    internal = 5432
    external = var.postgres_port
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "terraform_data" "wait_for_postgres" {
  depends_on = [docker_container.postgres]

  provisioner "local-exec" {
    command = <<-EOT
      timeout 60 sh -c 'until docker exec ${local.postgres_container_name} pg_isready -U postgres >/dev/null 2>&1; do sleep 2; done'
    EOT
  }
}

provider "postgresql" {
  host            = local.postgres_host
  port            = var.postgres_port
  database        = "postgres"
  username        = "postgres"
  password        = var.postgres_password
  sslmode         = "disable"
  connect_timeout = 15
}
