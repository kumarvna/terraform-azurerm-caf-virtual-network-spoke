variable "create_resource_group" {
  description = "Whether to create resource group and use it for all networking resources"
  default     = true
}

variable "resource_group_name" {
  description = "A container that holds related resources for an Azure solution"
  default     = ""
}

variable "location" {
  description = "The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  default     = ""
}

variable "spoke_vnet_name" {
  description = "The name of the spoke virtual network."
  default     = ""
}

variable "is_spoke_deployed_to_same_hub_subscription" {
  description = "Specify the Azure subscription to use to create the resoruces. possible to use diferent Azure subscription for spokes."
  default     = true
}

variable "vnet_address_space" {
  description = "The address space to be used for the Azure virtual network."
  default     = ["10.1.0.0/16"]
}

variable "create_ddos_plan" {
  description = "Create an ddos plan - Default is false"
  default     = false
}

variable "dns_servers" {
  description = "List of dns servers to use for virtual network"
  default     = []
}

variable "subnets" {
  description = "For each subnet, create an object that contain fields"
  default     = {}
}

variable "hub_virtual_network_id" {
  description = "The id of hub virutal network"
  default     = ""
}

variable "hub_firewall_private_ip_address" {
  description = "The private IP of the hub virtual network firewall"
  default     = null
}

variable "private_dns_zone_name" {
  description = "The name of the Hub Private DNS zone"
  default     = null
}

variable "use_remote_gateways" {
  description = "Controls if remote gateways can be used on the local virtual network."
  default     = false
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

variable "nsg_diag_logs" {
  description = "NSG Monitoring Category details for Azure Diagnostic setting"
  default     = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
