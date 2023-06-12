resource "azurecaf_name" "caf_name_spoke_rg" {
  name          = var.application_name
  resource_type = "azurerm_resource_group"
  prefixes      = concat(["spoke"], local.global_settings.prefixes)
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

resource "azurerm_resource_group" "spoke" {
  name     = azurecaf_name.caf_name_spoke_rg.result
  location = var.location

  tags = local.base_tags
}

resource "random_integer" "unique_id" {
  min = 1
  max = 9999
}

resource "azurecaf_name" "appsvc_subnet" {
  name          = var.application_name
  resource_type = "azurerm_subnet"
  prefixes      = concat(["spoke"], local.global_settings.prefixes)
  random_length = local.global_settings.random_length
  clean_input   = true
  passthrough   = local.global_settings.passthrough
  use_slug      = local.global_settings.use_slug
}

module "network" {
  source = "../../../../shared/terraform-modules/network"

  global_settings = local.global_settings
  resource_group  = azurerm_resource_group.spoke.name
  location        = var.location
  name            = var.application_name
  vnet_cidr       = var.spoke_vnet_cidr
  peering_vnet = {
    id             = data.azurerm_virtual_network.hub.id
    name           = data.azurerm_virtual_network.hub.name
    resource_group = data.azurerm_virtual_network.hub.resource_group_name
  }

  subnets = [
    {
      name        = "serverFarm"
      subnet_cidr = var.appsvc_subnet_cidr
      delegation = {
        name = "Microsoft.Web/serverFarms"
        service_delegation = {
          name    = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
    },
    {
      name        = "ingress"
      subnet_cidr = var.front_door_subnet_cidr
      delegation  = null
    },
    {
      name        = "devops"
      subnet_cidr = var.devops_subnet_cidr
      delegation  = null
    },
    {
      name        = "privateLink"
      subnet_cidr = var.private_link_subnet_cidr
      delegation  = null
    }
  ]

  tags = local.base_tags
}

module "private_dns_zones" {
  source = "../../../../shared/terraform-modules/private-dns-zone"

  resource_group  = data.terraform_remote_state.hub.outputs.rg_name
  global_settings = local.global_settings

  dns_zones = [
    "privatelink.azurewebsites.net",
    "privatelink.database.windows.net",
    "privatelink.azconfig.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.redis.cache.windows.net"
  ]

  vnet_links = [
    {
      vnet_id             = data.azurerm_virtual_network.hub.id
      vnet_resource_group = data.terraform_remote_state.hub.outputs.rg_name
    },
    {
      vnet_id             = module.network.vnet_id
      vnet_resource_group = azurerm_resource_group.spoke.name
    }
  ]

  tags = local.base_tags
}

module "user_defined_routes" {
  count = var.deployment_options.enable_egress_lockdown ? 1 : 0

  source = "../../../../shared/terraform-modules/user-defined-routes"

  resource_group   = azurerm_resource_group.spoke.name
  location         = var.location
  route_table_name = "egress-lockdown"
  global_settings  = local.global_settings

  routes = [
    {
      name                   = "defaultRoute"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = data.terraform_remote_state.hub.outputs.firewall_private_ip
    }
  ]

  subnet_ids = module.network.subnets[*].id
  tags       = local.base_tags
}


module "frontdoor" {
  source = "../../../../shared/terraform-modules/frontdoor"

  resource_group             = azurerm_resource_group.spoke.name
  application_name           = var.application_name
  environment                = var.environment
  location                   = var.location
  enable_waf                 = var.deployment_options.enable_waf
  unique_id                  = random_integer.unique_id.result
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  enable_diagnostic_settings = var.deployment_options.enable_diagnostic_settings
  global_settings            = local.global_settings

  endpoint_settings = [
    {
      endpoint_name            = "${var.application_name}-${var.environment}"
      web_app_id               = module.app_service.web_app_id
      web_app_hostname         = module.app_service.web_app_hostname
      private_link_target_type = "sites"
    },

    # Connecting a front door origin to an app service slot through private link is currently not supported
    # {
    #   endpoint_name            = "${var.application_name}-${var.environment}-${var.webapp_slot_name}"
    #   web_app_id               = module.app_service.web_app_id # Note: needs to be the resource id of the app, not the id of the slot
    #   web_app_hostname         = module.app_service.web_app_slot_hostname
    #   private_link_target_type = "sites-${var.slots[0].name]}"
    # }
  ]

  tags = local.base_tags

  depends_on = [
    module.app_service
  ]
}
