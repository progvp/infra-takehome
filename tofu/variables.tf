variable "k3d_cluster_name" {
  description = "Name of the k3d cluster"
  type        = string
  default     = "infra-takehome"
}

variable "k3s_version" {
  description = "K3s image tag to use for cluster nodes"
  type        = string
  default     = "v1.35.2-k3s1"
}

variable "postgres_password" {
  description = "Password for the PostgreSQL instance"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "postgres_port" {
  description = "Host port to expose PostgreSQL on"
  type        = number
  default     = 5432
}

variable "postgrest_namespace" {
  description = "Namespace for the PostgREST application"
  type        = string
  default     = "postgrest"
}

variable "postgrest_admin_user" {
  description = "Bootstrap superuser required by the task"
  type        = string
  default     = "postgrest_admin"
}

variable "postgrest_authenticator_user" {
  description = "Least-privilege runtime login used by PostgREST"
  type        = string
  default     = "authenticator"
}

variable "postgrest_anon_role" {
  description = "Anonymous role used by PostgREST for unauthenticated requests"
  type        = string
  default     = "web_anon"
}
