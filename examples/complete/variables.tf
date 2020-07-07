variable "hub_virtual_network_id" {
  description = "The id of hub virutal network"
  default     = ""
}

variable "hub_firewall_private_ip_address" {
  description = "The private IP of the hub virtual network firewall"
  default     = ""
}

variable "private_dns_zone_name" {
  description = "The name of the Private DNS zone"
  default     = null
}

variable "hub_storage_account_id" {
  description = "The id of hub storage id for logs storage"
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Specifies the id of the Log Analytics Workspace"
  default     = ""
}

variable "log_analytics_customer_id" {
  description = "The Workspace (or Customer) ID for the Log Analytics Workspace."
  default     = ""
}

variable "log_analytics_logs_retention_in_days" {
  description = "The log analytics workspace data retention in days. Possible values range between 30 and 730."
  default     = ""
}
