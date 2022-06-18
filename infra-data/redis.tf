locals {
  redis_namespace = "redis"
}

# NOTE: the Name used for Redis needs to be globally unique
resource "azurerm_redis_cache" "redis" {
  name                = "${local.prefix}-${local.redis_namespace}-cache"
  location            = var.location
  resource_group_name = var.resource_group_name
  # capacity            = 2
  capacity            = 0
  family              = "C"
  # sku_name            = "Standard"
  sku_name            = "Basic"
  enable_non_ssl_port = false # consider enable for dev
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}

output "redis_id" {
  value = azurerm_redis_cache.redis.id
}
output "redis_name" {
  value = azurerm_redis_cache.redis.name
}
output "redis_hostname" {
  value = azurerm_redis_cache.redis.hostname
}
output "redis_port" {
  value = azurerm_redis_cache.redis.port
}
output "redis_ssl_port" {
  value = azurerm_redis_cache.redis.ssl_port
}
output "redis_private_static_ip_address" {
  value = azurerm_redis_cache.redis.private_static_ip_address
}
output "redis_primary_access_key" {
  value = azurerm_redis_cache.redis.primary_access_key
  sensitive = true
}
output "redis_primary_connection_string" {
  value = azurerm_redis_cache.redis.primary_connection_string
  sensitive = true
}