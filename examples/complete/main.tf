module "vnet-spoke" {
  source  = "kumarvna/caf-virtual-network-spoke/azurerm"
  version = "2.0.0"

  # By default, this module will create a resource group, proivde the name here 
  # to use an existing resource group, specify the existing resource group name, 
  # and set the argument to `create_resource_group = false`. Location will be same as existing RG. 
  resource_group_name = "rg-spoke-demo-internal-shared-westeurope-001"
  location            = "westeurope"
  spoke_vnet_name     = "default-spoke"

  # Specify if you are deploying the spoke VNet using the same hub Azure subscription
  is_spoke_deployed_to_same_hub_subscription = true

  # Provide valid VNet Address space for spoke virtual network.  
  vnet_address_space = ["10.2.0.0/16"]

  # Hub network details to create peering and other setup
  hub_virtual_network_id          = "/subscriptions/f3410f97-ff27-4a79-b3ee-69a3e5c62beb/resourceGroups/rg-hub-demo-internal-shared-westeurope-001/providers/Microsoft.Network/virtualNetworks/vnet-default-hub-westeurope"
  hub_firewall_private_ip_address = "10.1.0.4"
  private_dns_zone_name           = "publiccloud.example.com"
  hub_storage_account_id          = "/subscriptions/f3410f97-ff27-4a79-b3ee-69a3e5c62beb/resourceGroups/rg-hub-demo-internal-shared-westeurope-001/providers/Microsoft.Storage/storageAccounts/stdiaglogsdefaulthub"

  # (Required) To enable Azure Monitoring and flow logs
  # pick the values for log analytics workspace which created by Hub module
  # Possible values range between 30 and 730
  log_analytics_workspace_id           = "/subscriptions/f3410f97-ff27-4a79-b3ee-69a3e5c62beb/resourcegroups/rg-hub-demo-internal-shared-westeurope-001/providers/microsoft.operationalinsights/workspaces/logaws-l2iokhxn-default-hub-westeurope"
  log_analytics_customer_id            = "612268ec-5ced-4320-8aab-f7b3d1146437"
  log_analytics_logs_retention_in_days = 30

  # Multiple Subnets, Service delegation, Service Endpoints, Network security groups
  # These are default subnets with required configuration, check README.md for more details
  # Route_table and NSG association to be added automatically for all subnets listed here.
  # subnet name will be set as per Azure naming convention by defaut. expected value here is: <App or project name>
  subnets = {

    app_subnet = {
      subnet_name           = "applicaiton"
      subnet_address_prefix = ["10.2.1.0/24"]
      service_endpoints     = ["Microsoft.Storage"]

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["ssh", "200", "Inbound", "Allow", "Tcp", "22", "*", ""],
        ["rdp", "201", "Inbound", "Allow", "Tcp", "3389", "*", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["ntp_out", "202", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }

    db_subnet = {
      subnet_name           = "database"
      subnet_address_prefix = ["10.2.2.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["http", "100", "Inbound", "Allow", "Tcp", "80", "*", "0.0.0.0/0"],
        ["sql_port", "101", "Inbound", "Allow", "Tcp", "1433", "*", ""],

      ]
      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any value and to use this subnet as a source or destination prefix.
        ["ntp_out", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }
  }

  # Adding TAG's to your Azure resources (Required)
  # ProjectName and Env are already declared above, to use them here, create a varible. 
  tags = {
    ProjectName  = "demo-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}
