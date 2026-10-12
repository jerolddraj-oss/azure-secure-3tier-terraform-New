resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-firewall-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                = "${var.name_prefix}-firewall-policy"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  threat_intelligence_mode = "Alert"
  tags                = var.tags
}

resource "azurerm_firewall" "this" {
  name                = "${var.name_prefix}-firewall"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }

  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "tier_rules" {
  name               = "tier-segmentation"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  network_rule_collection {
    name     = "tier-flows"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "Web-to-App-8080"
      protocols             = ["TCP"]
      source_addresses      = [var.web_subnet_cidr]
      destination_addresses = [var.app_subnet_cidr]
      destination_ports     = ["8080"]
    }

    rule {
      name                  = "App-to-SQL-1433"
      protocols             = ["TCP"]
      source_addresses      = [var.app_subnet_cidr]
      destination_addresses = [var.sql_subnet_cidr]
      destination_ports     = ["1433"]
    }
  }
}

output "firewall_id" {
  value = azurerm_firewall.this.id
}

output "private_ip_address" {
  value = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
