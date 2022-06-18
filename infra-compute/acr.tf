locals {
  acr_namespace = "acr"
  acr_container_registry_name = "sazacr"
}

resource "azurerm_container_registry" "acr" {
  name                = local.acr_container_registry_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  admin_enabled       = false
}