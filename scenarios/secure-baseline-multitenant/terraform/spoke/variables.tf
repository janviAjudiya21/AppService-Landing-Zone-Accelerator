variable "global_settings" {
  type        = map(any)
  description = "[Optional] Global settings to configure each module with the appropriate naming standards."
  default     = {}
}

variable "owner" {
  type        = string
  description = "[Required] Owner of the deployment."
}

variable "hub_state_resource_group_name" {
  type        = string
  description = "The name of the resource group that holds the Terraform state for the hub"
}

variable "hub_state_storage_account_name" {
  type        = string
  description = "The name of the storage account that holds the Terraform state for the hub"
}

variable "hub_state_container_name" {
  type        = string
  description = "The name of the container that holds the Terraform state for the hub"
}

variable "hub_state_key" {
  type        = string
  description = "The key of the Terraform state for the hub"
}

variable "application_name" {
  type        = string
  description = "The name of your application"
  default     = "sec-baseline-1-spoke"
}

variable "environment" {
  type        = string
  description = "The environment (dev, qa, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "The Azure region where all resources in this example should be created"
  default     = "westus2"
}

variable "tenant_id" {
  type        = string
  description = "The Azure AD tenant ID for the identities. If no value provided, will use current deployment environment tenant."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "[Optional] Additional tags to assign to your resources"
  default     = {}
}

#####################################
# Spoke Resource Configuration Variables
#####################################
variable "aad_admin_group_object_id" {
  type        = string
  description = "The object ID of the Azure AD group that should be granted SQL Admin permissions to the SQL Server"
}

variable "aad_admin_group_name" {
  type        = string
  description = "The name of the Azure AD group that should be granted SQL Admin permissions to the SQL Server"
}

variable "bastion_subnet_name" {
  type        = string
  description = "[Optional] Name of the subnet to deploy bastion resource to. Defaults to 'AzureBastionSubnet'"
  default     = "AzureBastionSubnet"
}

variable "firewall_subnet_name" {
  type        = string
  description = "[Optional] Name of the subnet for firewall resources. Defaults to 'AzureFirewallSubnet'"
  default     = "AzureFirewallSubnet"
}
variable "hub_vnet_cidr" {
  type        = list(string)
  description = "[Optional] The CIDR block(s) for the hub virtual network. Defaults to 10.242.0.0/20"
  default     = ["10.242.0.0/20"]
}

variable "firewall_subnet_cidr" {
  type        = list(string)
  description = "[Optional] The CIDR block(s) for the firewall subnet. Defaults to 10.242.0.0/26"
  default     = ["10.242.0.0/26"]
}

variable "bastion_subnet_cidr" {
  type        = list(string)
  description = "[Optional] The CIDR block(s) for the bastion subnet. Defaults to 10.242.0.64/26"
  default     = ["10.242.0.64/26"]
}

variable "spoke_vnet_cidr" {
  type        = list(string)
  description = "[Optional] The CIDR block(s) for the virtual network for whitelisting on the firewall. Defaults to 10.240.0.0/20"
  default     = ["10.240.0.0/20"]
}

variable "devops_subnet_cidr" {
  type        = list(string)
  description = "[Optional] The CIDR block for the subnet. Defaults to 10.240.10.128/16"
  default     = ["10.240.10.128/26"]
}

variable "appsvc_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = ["10.240.0.0/26"]
}

variable "front_door_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = ["10.240.0.64/26"]
}


variable "private_link_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = ["10.240.11.0/24"]
}

# variable "hub_settings" {
#   type = object({
#     rg_name   = string
#     vnet_name = string

#     firewall = object({
#       private_ip = optional(string)
#     })
#   })

#   description = "The settings for the hub virtual network."

#   default = null
# }

variable "vm_admin_username" {
  type        = string
  description = "The username for the local VM admin account. Autogenerated if null. Prefer using the Azure AD admin account."
  default     = null
}

variable "vm_admin_password" {
  type        = string
  description = "The password for the local VM admin account. Autogenerated if null. Prefer using the Azure AD admin account."
  default     = null
}

variable "vm_aad_admin_username" {
  type        = string
  description = "[Optional] The Azure AD username for the VM admin account. If vm_aad_admin_object_id is not specified, this value will be used."
  default     = null
}
variable "vm_aad_admin_object_id" {
  type        = string
  description = "The Azure AD object ID for the VM admin user/group. If vm_aad_admin_username is not specified, this value will be used."
  default     = null
}
variable "deployment_options" {
  type = object({
    enable_waf                 = bool
    enable_egress_lockdown     = bool
    enable_diagnostic_settings = bool
    deploy_bastion             = bool
    deploy_redis               = bool
    deploy_sql_database        = bool
    deploy_app_config          = bool
    deploy_vm                  = bool
  })

  description = "Opt-in settings for the deployment: enable WAF in Front Door, deploy Azure Firewall and UDRs in the spoke network to force outbound traffic to the Azure Firewall, deploy Redis Cache."

  default = {
    enable_waf                 = true
    enable_egress_lockdown     = true
    enable_diagnostic_settings = true
    deploy_bastion             = true
    deploy_redis               = true
    deploy_sql_database        = true
    deploy_app_config          = true
    deploy_vm                  = true
  }
}

variable "appsvc_options" {
  type = object({
    service_plan = object({
      os_type        = string
      sku_name       = string
      worker_count   = optional(number)
      zone_redundant = optional(bool)
    })
    web_app = object({
      slots = list(string)

      application_stack = object({
        current_stack       = string # required for windows
        dotnet_version      = optional(string)
        php_version         = optional(string)
        node_version        = optional(string)
        java_version        = optional(string)
        python              = optional(bool)   # windows only
        python_version      = optional(string) # linux only
        java_server         = optional(string) # linux only
        java_server_version = optional(string) # linux only
        go_version          = optional(string) # linux only
        docker_image        = optional(string) # linux only
        docker_image_tag    = optional(string) # linux only
        go_version          = optional(string) # linux only
        ruby_version        = optional(string) # linux only
      })
    })
  })

  description = "The options for the app service"

  default = {
    service_plan = {
      os_type  = "Windows"
      sku_name = "S1"
    }
    web_app = {
      slots = []

      application_stack = {
        current_stack  = "dotnet"
        dotnet_version = "6.0"
      }
    }
  }

  validation {
    condition     = contains(["Windows", "Linux"], var.appsvc_options.service_plan.os_type)
    error_message = "Please, choose among one of the following operating systems: Windows or Linux."
  }

  # validation {
  #   condition     = contains(["S1", "S2", "S3", "P1v2", "P2v2", "P3v2"], var.appsvc_options.service_plan.sku_name)
  #   error_message = "Please, choose among one of the following SKUs for production workloads: S1, S2, S3, P1v2, P2v2 or P3v2."
  # }

  validation {
    condition     = contains(["dotnet", "dotnetcore", "java", "php", "python", "node"], var.appsvc_options.web_app.application_stack.current_stack)
    error_message = "Please, choose among one of the following stacks: dotnet, dotnetcore, java, php, python or node."
  }
}

variable "devops_settings" {
  type = object({
    github_runner = optional(object({
      repository_url = string
      token          = string
    }))

    devops_agent = optional(object({
      organization_url = string
      token            = string
    }))
  })

  description = "The settings for the Azure DevOps agent or GitHub runner"

  default = {
    github_runner = null
    devops_agent  = null
  }
}