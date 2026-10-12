terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id              = var.subscription_id
  resource_provider_registrations = "none"
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

module "hub_network" {
  source               = "../../modules/hub-network"
  name_prefix          = var.name_prefix
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.this.name
  hub_cidr             = var.hub_cidr
  firewall_subnet_cidr = var.firewall_subnet_cidr
  appgw_subnet_cidr    = var.appgw_subnet_cidr
  tags                 = var.tags
}

module "web_spoke" {
  source               = "../../modules/spoke-network"
  name                 = "${var.name_prefix}-web"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.this.name
  vnet_cidr            = var.web_vnet_cidr
  subnet_name          = "web"
  subnet_cidr          = var.web_subnet_cidr
  tags                 = var.tags
}

module "app_spoke" {
  source               = "../../modules/spoke-network"
  name                 = "${var.name_prefix}-app"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.this.name
  vnet_cidr            = var.app_vnet_cidr
  subnet_name          = "app"
  subnet_cidr          = var.app_subnet_cidr
  tags                 = var.tags
}

module "sql_spoke" {
  source                            = "../../modules/spoke-network"
  name                              = "${var.name_prefix}-sql"
  location                          = var.location
  resource_group_name               = data.azurerm_resource_group.this.name
  vnet_cidr                         = var.sql_vnet_cidr
  subnet_name                       = "private-endpoints"
  subnet_cidr                       = var.sql_subnet_cidr
  private_endpoint_network_policies = "Disabled"
  tags                              = var.tags
}

module "hub_peering" {
  source              = "../../modules/hub-peering"
  resource_group_name = data.azurerm_resource_group.this.name
  hub_vnet_name       = module.hub_network.vnet_name
  hub_vnet_id         = module.hub_network.vnet_id
  web_vnet_name       = module.web_spoke.vnet_name
  web_vnet_id         = module.web_spoke.vnet_id
  app_vnet_name       = module.app_spoke.vnet_name
  app_vnet_id         = module.app_spoke.vnet_id
  sql_vnet_name       = module.sql_spoke.vnet_name
  sql_vnet_id         = module.sql_spoke.vnet_id
}

# The full module implementations are composed in their own modules directories.
# Review the module READMEs and implementation notes before enabling deployment.
module "firewall" {
  source              = "../../modules/firewall"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  firewall_subnet_id  = module.hub_network.firewall_subnet_id
  web_subnet_cidr     = var.web_subnet_cidr
  app_subnet_cidr     = var.app_subnet_cidr
  sql_subnet_cidr     = var.sql_subnet_cidr
  tags                = var.tags
}

module "routes" {
  source              = "../../modules/routes"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  firewall_private_ip = module.firewall.private_ip_address
  web_subnet_id       = module.web_spoke.subnet_id
  app_subnet_id       = module.app_spoke.subnet_id
  sql_subnet_id       = module.sql_spoke.subnet_id
  web_vnet_cidr       = var.web_vnet_cidr
  app_vnet_cidr       = var.app_vnet_cidr
  sql_vnet_cidr       = var.sql_vnet_cidr
  tags                = var.tags
}

module "security" {
  source              = "../../modules/security"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  web_subnet_id       = module.web_spoke.subnet_id
  app_subnet_id       = module.app_spoke.subnet_id
  sql_subnet_id       = module.sql_spoke.subnet_id
  appgw_subnet_cidr   = var.appgw_subnet_cidr
  web_subnet_cidr     = var.web_subnet_cidr
  app_subnet_cidr     = var.app_subnet_cidr
  tags                = var.tags
}

module "workload_vms" {
  source              = "../../modules/workload-vms"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  web_subnet_id       = module.web_spoke.subnet_id
  app_subnet_id       = module.app_spoke.subnet_id
  web_private_ip      = var.web_private_ip
  app_private_ip      = var.app_private_ip
  admin_username      = var.admin_username
  ssh_public_key       = var.ssh_public_key
  tags                = var.tags
}

module "application_gateway" {
  source                     = "../../modules/application-gateway"
  name_prefix                = var.name_prefix
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.this.name
  appgw_subnet_id            = module.hub_network.appgw_subnet_id
  web_backend_ip             = module.workload_vms.web_private_ip
  tls_certificate_pfx_base64 = var.tls_certificate_pfx_base64
  tls_certificate_password   = var.tls_certificate_password
  tags                       = var.tags
}

module "sql_private" {
  source                    = "../../modules/sql-private"
  name_prefix               = var.name_prefix
  location                  = var.location
  resource_group_name       = data.azurerm_resource_group.this.name
  private_endpoint_subnet_id = module.sql_spoke.subnet_id
  hub_vnet_id               = module.hub_network.vnet_id
  web_vnet_id               = module.web_spoke.vnet_id
  app_vnet_id               = module.app_spoke.vnet_id
  sql_vnet_id               = module.sql_spoke.vnet_id
  sql_admin_username        = var.sql_admin_username
  sql_admin_password        = var.sql_admin_password
  tags                      = var.tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  firewall_id         = module.firewall.firewall_id
  tags                = var.tags
}
