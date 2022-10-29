#---------------------------------
# Local declarations
#---------------------------------
locals {
  resource_group_name    = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location               = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
  netwatcher_rg_name     = element(coalescelist(data.azurerm_resource_group.netwatch.*.name, azurerm_resource_group.nwatcher.*.name, [""]), 0)
  netwatcher_rg_location = element(coalescelist(data.azurerm_resource_group.netwatch.*.location, azurerm_resource_group.nwatcher.*.location, [""]), 0)
  if_ddos_enabled        = var.create_ddos_plan ? [{}] : []
}

#-------------------------------------
# Azure Provider Alias for Peering
#-------------------------------------
provider "azurerm" {
  alias           = "hub"
  subscription_id = element(split("/", var.hub_virtual_network_id), 2)
  features {}
}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group_name)
  location = var.location
  tags     = merge({ "ResourceName" = format("%s", var.resource_group_name) }, var.tags, )
}

#-------------------------------------
# VNET Creation - Default is "true"
#-------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = lower("vnet-spoke-${var.spoke_vnet_name}-${local.location}")
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  tags                = merge({ "ResourceName" = lower("vnet-spoke-${var.spoke_vnet_name}-${local.location}") }, var.tags, )

  dynamic "ddos_protection_plan" {
    for_each = local.if_ddos_enabled

    content {
      id     = azurerm_network_ddos_protection_plan.ddos[0].id
      enable = true
    }
  }
}

#--------------------------------------------
# Ddos protection plan - Default is "false"
#--------------------------------------------
resource "azurerm_network_ddos_protection_plan" "ddos" {
  count               = var.create_ddos_plan ? 1 : 0
  name                = lower("${var.spoke_vnet_name}-ddos-protection-plan")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("${var.spoke_vnet_name}-ddos-protection-plan") }, var.tags, )
}

#-------------------------------------
# Network Watcher - Default is "true"
#-------------------------------------
data "azurerm_resource_group" "netwatch" {
  count = var.is_spoke_deployed_to_same_hub_subscription == true ? 1 : 0
  name  = "NetworkWatcherRG"
}

resource "azurerm_resource_group" "nwatcher" {
  count    = var.is_spoke_deployed_to_same_hub_subscription == false ? 1 : 0
  name     = "NetworkWatcherRG"
  location = local.location
  tags     = merge({ "ResourceName" = "NetworkWatcherRG" }, var.tags, )
}

resource "azurerm_network_watcher" "nwatcher" {
  count               = var.is_spoke_deployed_to_same_hub_subscription == false ? 1 : 0
  name                = "NetworkWatcher_${local.location}"
  location            = local.netwatcher_rg_location
  resource_group_name = local.netwatcher_rg_name
  tags                = merge({ "ResourceName" = format("%s", "NetworkWatcher_${local.location}") }, var.tags, )
}

#--------------------------------------------------------------------------------------------------------
# Subnets Creation with, private link endpoint/servie network policies, service endpoints and Deligation.
#--------------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "snet" {
  for_each             = var.subnets
  name                 = lower(format("snet-%s-${var.spoke_vnet_name}-${local.location}", each.value.subnet_name))
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.subnet_address_prefix
  service_endpoints    = lookup(each.value, "service_endpoints", [])
  # Applicable to the subnets which used for Private link endpoints or services 
  private_endpoint_network_policies_enabled     = lookup(each.value, "private_endpoint_network_policies_enabled", null)
  private_link_service_network_policies_enabled = lookup(each.value, "private_link_service_network_policies_enabled", null)

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", {}) != {} ? [1] : []
    content {
      name = lookup(each.value.delegation, "name", null)
      service_delegation {
        name    = lookup(each.value.delegation.service_delegation, "name", null)
        actions = lookup(each.value.delegation.service_delegation, "actions", null)
      }
    }
  }
}

#---------------------------------------------------------------
# Network security group - NSG created for every subnet in VNet
#---------------------------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnets
  name                = lower("nsg_${each.key}_in")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("nsg_${each.key}_in") }, var.tags, )
  dynamic "security_rule" {
    for_each = concat(lookup(each.value, "nsg_inbound_rules", []), lookup(each.value, "nsg_outbound_rules", []))
    content {
      name                       = security_rule.value[0] == "" ? "Default_Rule" : security_rule.value[0]
      priority                   = security_rule.value[1]
      direction                  = security_rule.value[2] == "" ? "Inbound" : security_rule.value[2]
      access                     = security_rule.value[3] == "" ? "Allow" : security_rule.value[3]
      protocol                   = security_rule.value[4] == "" ? "Tcp" : security_rule.value[4]
      source_port_range          = "*"
      destination_port_range     = security_rule.value[5] == "" ? "*" : security_rule.value[5]
      source_address_prefix      = security_rule.value[6] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[6]
      destination_address_prefix = security_rule.value[7] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[7]
      description                = "${security_rule.value[2]}_Port_${security_rule.value[5]}"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.snet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

#-------------------------------------------------
# route_table to dirvert traffic through Firewall
#-------------------------------------------------
resource "azurerm_route_table" "rtout" {
  name                = "route-network-outbound"
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = "route-network-outbound" }, var.tags, )
}

resource "azurerm_subnet_route_table_association" "rtassoc" {
  for_each       = var.subnets
  subnet_id      = azurerm_subnet.snet[each.key].id
  route_table_id = azurerm_route_table.rtout.id
}

resource "azurerm_route" "rt" {
  count                  = var.hub_firewall_private_ip_address != null ? 1 : 0
  name                   = lower("route-to-firewall-${var.spoke_vnet_name}-${local.location}")
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.rtout.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.hub_firewall_private_ip_address
}

#---------------------------------------------
# Linking Spoke Vnet to Hub Private DNS Zone
#---------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "dzvlink" {
  provider              = azurerm.hub
  count                 = var.private_dns_zone_name != null ? 1 : 0
  name                  = lower("${var.private_dns_zone_name}-link-to-hub")
  resource_group_name   = element(split("/", var.hub_virtual_network_id), 4)
  virtual_network_id    = azurerm_virtual_network.vnet.id
  private_dns_zone_name = var.private_dns_zone_name
  registration_enabled  = true
  tags                  = merge({ "ResourceName" = format("%s", lower("${var.private_dns_zone_name}-link-to-hub")) }, var.tags, )
}

#-----------------------------------------------
# Peering between Hub and Spoke Virtual Network
#-----------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = lower("peering-to-hub-${element(split("/", var.hub_virtual_network_id), 8)}")
  resource_group_name          = local.resource_group_name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = var.hub_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.hub
  name                         = lower("peering-${element(split("/", var.hub_virtual_network_id), 8)}-to-spoke")
  resource_group_name          = element(split("/", var.hub_virtual_network_id), 4)
  virtual_network_name         = element(split("/", var.hub_virtual_network_id), 8)
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_gateway_transit        = true
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

#-----------------------------------------
# Network flow logs for subnet and NSG
#-----------------------------------------
resource "azurerm_network_watcher_flow_log" "nwflog" {
  for_each                  = var.subnets
  name                      = lower("network-watcher-flow-log")
  network_watcher_name      = var.is_spoke_deployed_to_same_hub_subscription == true ? "NetworkWatcher_${local.netwatcher_rg_location}" : azurerm_network_watcher.nwatcher.0.name
  resource_group_name       = local.netwatcher_rg_name # Must provide Netwatcher resource Group
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  storage_account_id        = var.hub_storage_account_id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 0
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.log_analytics_customer_id
    workspace_region      = local.location
    workspace_resource_id = var.log_analytics_workspace_id
    interval_in_minutes   = 10
  }
}

#---------------------------------------------------------------
# azurerm monitoring diagnostics - VNet, NSG, PIP, and Firewall
#---------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name                       = lower("vnet-${var.spoke_vnet_name}-diag")
  target_resource_id         = azurerm_virtual_network.vnet.id
  storage_account_id         = var.hub_storage_account_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  log {
    category = "VMProtectionAlerts"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each                   = var.subnets
  name                       = lower("${each.key}-diag")
  target_resource_id         = azurerm_network_security_group.nsg[each.key].id
  storage_account_id         = var.hub_storage_account_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "log" {
    for_each = var.nsg_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }
  }
}
