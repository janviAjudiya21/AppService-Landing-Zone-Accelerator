application_name = "eslz200"
environment      = "prod"
location         = "eastus"
owner            = "janvi.ajudiya@celebaltech.com"

# For the hub state, use the same settings as the remote state config on the hub deployment from /hub/main.tf
hub_state_resource_group_name  = "backend-appsrvc-production-eastus-001"
hub_state_storage_account_name = "stbackendappsreastus001"
hub_state_container_name       = "tfstate"
hub_state_key                  = "scenario1.hub.tfstate"

entra_admin_group_object_id = "bda41c64-1493-4d8d-b4b5-7135159d4884"
entra_admin_group_name      = "AppSvcLZA Microsoft Entra SQL Admins"

## Lookup the Microsoft Entra User
# vm_entra_admin_username = "my-user@contoso.com"
## Reference an existing Microsoft Entra User/Group Object ID to bypass lookup
vm_entra_admin_object_id = "bda41c64-1493-4d8d-b4b5-7135159d4884" # "AppSvcLZA Microsoft Entra SQL Admins"


## Optionally provide non-Entra ID admin credentials for the VM
# vm_admin_username         = "daniem"
# vm_admin_password         = "**************"

## These settings are used for peering the spoke to the hub. Fill in the appropriate settings for your environment
hub_settings = {
  rg_name   = "rg-hub-merge-ase-dev-westus2"
  vnet_name = "vnet-merge-ase-dev-wus2-hub"

  firewall = {
    private_ip = "10.242.0.4"
  }
}

## Toggle deployment of optional features and services for the Landing Zone
deployment_options = {
  enable_waf                 = true
  enable_egress_lockdown     = true
  enable_diagnostic_settings = true
  deploy_bastion             = true
  deploy_redis               = true
  deploy_sql_database        = false
  deploy_app_config          = true
  deploy_vm                  = false
  deploy_openai              = true
}

## Optionally deploy a Github runner, DevOps agent, or both to the VM. 
# devops_settings = {
#   github_runner = {
#     repository_url = "https://github.com/{organization}/{repository}"
#     token          = "runner_registration_token" # See: https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28
#   }
# 
#   devops_agent = {
#     organization_url = "https://dev.azure.com/{organization}/"
#     token            = "pat_token"
#   }
# }

appsvc_options = {
  service_plan = {
    os_type  = "Windows"
    sku_name = "S1"

    # Optionally configure zone redundancy (requires a minimum of three workers and Premium SKU service plan) 
    # worker_count   = 3
    # zone_redundant = true
  }

  web_app = {
    application_stack = {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
    slots = ["staging"]
  }
}
