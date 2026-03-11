resource "terraform_data" "wait_for_kubeapi" {
  depends_on = [terraform_data.k3d_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --context ${local.kube_context} wait --for=condition=Ready nodes --all --timeout=120s
    EOT
  }
}

resource "terraform_data" "postgrest_namespace" {
  depends_on = [
    terraform_data.k3d_cluster,
    terraform_data.wait_for_kubeapi,
  ]

  input = {
    namespace    = "postgrest"
    kube_context = local.kube_context
  }

  provisioner "local-exec" {
    command = "kubectl --context ${self.input.kube_context} create namespace ${self.input.namespace} --dry-run=client -o yaml | kubectl --context ${self.input.kube_context} apply -f -"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --context ${self.input.kube_context} delete namespace ${self.input.namespace} --ignore-not-found=true"
  }
}

resource "terraform_data" "postgrest_secrets" {
  depends_on = [
    terraform_data.postgrest_namespace,
    terraform_data.postgrest_database_bootstrap,
  ]

  input = {
    namespace              = var.postgrest_namespace
    admin_user             = postgresql_role.postgrest_admin.name
    admin_password         = random_password.postgrest_admin.result
    authenticator_user     = postgresql_role.authenticator.name
    authenticator_password = random_password.postgrest_authenticator.result
    db_name                = postgresql_database.postgrest.name
    anon_role              = postgresql_role.web_anon.name
    postgres_port          = var.postgres_port
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'YAML' | kubectl --context ${local.kube_context} apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: postgrest-admin
        namespace: ${self.input.namespace}
      type: Opaque
      stringData:
        POSTGRES_USER: "${self.input.admin_user}"
        POSTGRES_PASSWORD: "${self.input.admin_password}"
        POSTGRES_DB: "${self.input.db_name}"
        POSTGRES_SCHEMA_OWNER: "${self.input.admin_user}"
        POSTGREST_ANON_ROLE: "${self.input.anon_role}"
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: postgrest-runtime
        namespace: ${self.input.namespace}
      type: Opaque
      stringData:
        PGRST_DB_URI: "postgres://${self.input.authenticator_user}:${self.input.authenticator_password}@host.k3d.internal:${self.input.postgres_port}/${self.input.db_name}"
        PGRST_DB_SCHEMAS: "api"
        PGRST_DB_ANON_ROLE: "${self.input.anon_role}"
      YAML
    EOT
  }
}
