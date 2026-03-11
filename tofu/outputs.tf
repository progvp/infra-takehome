output "cluster_name" {
  description = "Name of the k3d cluster"
  value       = var.k3d_cluster_name
}

output "kube_context" {
  description = "kubectl context name for the k3d cluster"
  value       = local.kube_context
}

output "postgres_host" {
  description = "PostgreSQL connection host from the local machine"
  value       = local.postgres_host
}

output "postgres_port" {
  description = "PostgreSQL connection port"
  value       = var.postgres_port
}

output "postgres_database" {
  description = "Database created for PostgREST"
  value       = postgresql_database.postgrest.name
}

output "postgrest_url" {
  description = "Expected browser URL for the PostgREST endpoint"
  value       = "http://localhost:8080/todos"
}

output "postgrest_admin_secret_name" {
  description = "Kubernetes secret used by the seed job"
  value       = "postgrest-admin"
}

output "postgrest_runtime_secret_name" {
  description = "Kubernetes secret used by the PostgREST deployment"
  value       = "postgrest-runtime"
}
