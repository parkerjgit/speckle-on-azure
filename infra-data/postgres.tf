locals {
  postgresql_namespace = "psql"
  postgresql_server_name = "${local.prefix}-${local.postgresql_namespace}-server"
  postgresql_database_name = "${local.prefix}-${local.postgresql_namespace}-db"
}

# Create server (see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_server)
resource "azurerm_postgresql_server" "psql" {
  name = local.postgresql_server_name
  location = var.location
  resource_group_name = var.resource_group_name

  sku_name = "B_Gen5_1" # tier + family + cores (see https://azure.microsoft.com/en-us/pricing/details/postgresql/server/#pricing)
  storage_mb = "5120" # 5 GB (min) - can be configured between 5 GB and 1 TB (for basic)
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled = true

  administrator_login = var.db_username
  administrator_login_password = var.db_password
  ssl_enforcement_enabled = true # consider disable for dev
  version = "11"

  tags = local.common_tags
}

# Create postgres db (see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_database)
resource "azurerm_postgresql_database" "psql" {
  name = local.postgresql_database_name
  resource_group_name = var.resource_group_name
  server_name = azurerm_postgresql_server.psql.name
  charset = "UTF8"
  collation = "English_United States.1252"
}

# Create firewall rule (https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_firewall_rule)
# Allow all internal azure services access to database (see https://docs.microsoft.com/en-us/rest/api/sql/2021-02-01-preview/firewall-rules/create-or-update)
resource "azurerm_postgresql_firewall_rule" "allow-azure-internal" {
  end_ip_address = "0.0.0.0"
  start_ip_address = "0.0.0.0"
  name = "allow-azure-internal"
  resource_group_name = var.resource_group_name
  server_name = azurerm_postgresql_server.psql.name
}

# Allow local connection
# get external IP: curl "http://myexternalip.com/raw"
resource "azurerm_postgresql_firewall_rule" "allow-client" {
  end_ip_address = "74.122.111.100"
  start_ip_address = "74.122.111.100"
  name = "allow-client"
  resource_group_name = var.resource_group_name
  server_name = azurerm_postgresql_server.psql.name
}