variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vnet_cidr" { type = string }
variable "subnet_name" { type = string }
variable "subnet_cidr" { type = string }
variable "private_endpoint_network_policies" {
  type    = string
  default = "Disabled"
}
variable "tags" {
  type    = map(string)
  default = {}
}
