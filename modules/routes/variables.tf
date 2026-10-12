variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "firewall_private_ip" {
  type = string
}

variable "web_subnet_id" {
  type = string
}

variable "app_subnet_id" {
  type = string
}

variable "sql_subnet_id" {
  type = string
}

variable "web_vnet_cidr" {
  type = string
}

variable "app_vnet_cidr" {
  type = string
}

variable "sql_vnet_cidr" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
