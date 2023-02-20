variable "application_name" {
  type        = string
  description = "The name of your application"
  default     = "secure-baseline"
}

variable "environment" {
  type        = string
  description = "The environment (dev, qa, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "The Azure region where all resources in this example should be created"
  default     = "westeurope"
}

variable "tenant_id" {
  type        = string
  description = "The Azure AD tenant ID for the identities"
}

variable "aad_admin_group_object_id" {
  type        = string
  description = "The object ID of the Azure AD group that should be granted SQL Admin permissions to the SQL Server"
}

variable "aad_admin_group_name" {
  type        = string
  description = "The name of the Azure AD group that should be granted SQL Admin permissions to the SQL Server"
}

variable "hub_vnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the hub virtual network."
  default     = null
}

variable "firewall_subnet_cidr" {
  type        = string
  description = "The CIDR block for the firewall subnet."
  default     = null
}

variable "bastion_subnet_cidr" {
  type        = string
  description = "The CIDR block for the bastion subnet."
  default     = null
}

variable "spoke_vnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the virtual network."
  default     = null
}

variable "appsvc_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = null
}

variable "front_door_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = null
}

variable "devops_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = null
}

variable "private_link_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the subnet."
  default     = null
}

variable "vm_admin_username" {
  type        = string
  description = "The username for the local VM admin account. Prefer using the Azure AD admin account."
  default     = null
}

variable "vm_admin_password" {
  type        = string
  description = "The password for the local VM admin account. Prefer using the Azure AD admin account."
  default     = null
}

variable "vm_aad_admin_username" {
  type        = string
  description = "The Azure AD username for the VM admin account."
}

variable "deployment_options" {
  type = object({
    enable_waf             = bool
    enable_egress_lockdown = bool
    deploy_bastion         = bool
    deploy_redis           = bool
    deploy_sql_database    = bool
    deploy_app_config      = bool
    deploy_vm              = bool
  })

  description = "Opt-in settings for the deployment: enable WAF in Front Door, deploy Azure Firewall and UDRs in the spoke network to force outbound traffic to the Azure Firewall, deploy Redis Cache."

  default = {
    enable_waf             = true
    enable_egress_lockdown = true
    deploy_bastion         = true
    deploy_redis           = true
    deploy_sql_database    = true
    deploy_app_config      = true
    deploy_vm              = true
  }
}

variable "appsvc_options" {
  type = object({
    service_plan = object({
      os_type  = string
      sku_name = string
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

  validation {
    condition     = contains(["S1", "S2", "S3", "P1v2", "P2v2", "P3v2"], var.appsvc_options.service_plan.sku_name)
    error_message = "Please, choose among one of the following SKUs for production workloads: S1, S2, S3, P1v2, P2v2 or P3v2."
  }

  validation {
    condition     = contains(["dotnet", "dotnetcore", "java", "php", "python", "node"], var.appsvc_options.web_app.application_stack.current_stack)
    error_message = "Please, choose among one of the following stacks: dotnet, dotnetcore, java, php, python or node."
  }
}

