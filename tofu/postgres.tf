resource "time_sleep" "wait_for_postgres_stable" {
  depends_on = [terraform_data.wait_for_postgres]

  create_duration = "10s"
}

resource "postgresql_database" "postgrest" {
  depends_on = [time_sleep.wait_for_postgres_stable]

  name = local.postgres_db_name
}

resource "random_password" "postgrest_admin" {
  length  = 32
  special = false
}

resource "random_password" "postgrest_authenticator" {
  length  = 32
  special = false
}

resource "postgresql_role" "postgrest_admin" {
  name       = var.postgrest_admin_user
  login      = true
  superuser  = true
  password   = random_password.postgrest_admin.result
  depends_on = [postgresql_database.postgrest]
}

resource "postgresql_role" "web_anon" {
  name       = var.postgrest_anon_role
  login      = false
  depends_on = [postgresql_database.postgrest]
}

resource "postgresql_role" "authenticator" {
  name       = var.postgrest_authenticator_user
  login      = true
  inherit    = false
  password   = random_password.postgrest_authenticator.result
  depends_on = [postgresql_database.postgrest]
}

resource "terraform_data" "postgrest_database_bootstrap" {
  depends_on = [
    postgresql_database.postgrest,
    postgresql_role.postgrest_admin,
    postgresql_role.web_anon,
    postgresql_role.authenticator,
  ]

  input = {
    admin_user         = postgresql_role.postgrest_admin.name
    authenticator_user = postgresql_role.authenticator.name
    anon_role          = postgresql_role.web_anon.name
    db_name            = postgresql_database.postgrest.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker exec -e PGPASSWORD='${var.postgres_password}' ${local.postgres_container_name} \
        psql -v ON_ERROR_STOP=1 -U postgres -d ${self.input.db_name} \
          -c "CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION ${self.input.admin_user};" \
          -c "ALTER SCHEMA api OWNER TO ${self.input.admin_user};" \
          -c "GRANT CONNECT ON DATABASE ${self.input.db_name} TO ${self.input.authenticator_user};" \
          -c "GRANT USAGE ON SCHEMA api TO ${self.input.anon_role};" \
          -c "GRANT ${self.input.anon_role} TO ${self.input.authenticator_user};"
    EOT
  }
}
