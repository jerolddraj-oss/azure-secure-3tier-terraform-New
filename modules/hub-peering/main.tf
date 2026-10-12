resource "azurerm_virtual_network_peering" "hub_web" {
  name                         = "hub-to-web"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = var.web_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "web_hub" {
  name                         = "web-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.web_vnet_name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "hub_app" {
  name                         = "hub-to-app"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = var.app_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "app_hub" {
  name                         = "app-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.app_vnet_name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "hub_sql" {
  name                         = "hub-to-sql"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = var.sql_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "sql_hub" {
  name                         = "sql-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.sql_vnet_name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
