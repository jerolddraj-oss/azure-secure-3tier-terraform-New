variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "appgw_subnet_id" { type = string }
variable "web_backend_ip" { type = string }
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
variable "tags" {
  type    = map(string)
  default = {}
}
