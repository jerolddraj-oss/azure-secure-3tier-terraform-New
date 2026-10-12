variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "East US"
}

variable "name_prefix" {
  type    = string
  default = "secure3tier"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "Use 3-12 lowercase letters and digits."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "hub_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "firewall_subnet_cidr" {
  type    = string
  default = "10.0.0.0/26"
}

variable "appgw_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "web_vnet_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "web_subnet_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "app_vnet_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "app_subnet_cidr" {
  type    = string
  default = "10.2.1.0/24"
}

variable "sql_vnet_cidr" {
  type    = string
  default = "10.3.0.0/16"
}

variable "sql_subnet_cidr" {
  type    = string
  default = "10.3.1.0/24"
}

variable "web_private_ip" {
  type    = string
  default = "10.1.1.4"
}

variable "app_private_ip" {
  type    = string
  default = "10.2.1.4"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "tls_certificate_pfx_base64" {
  type      = string
  sensitive = true
  default   = ""
}

variable "tls_certificate_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "sql_admin_username" {
  type    = string
  default = "sqlbootstrapadmin"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
  default   = "PlaceholderOnly-ChangeMe123!"
}
