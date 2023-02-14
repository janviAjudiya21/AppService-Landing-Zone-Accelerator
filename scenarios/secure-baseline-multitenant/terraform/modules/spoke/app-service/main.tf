terraform {
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = ">=1.2.22"
    }
  }
}

locals {
  app-svc-plan-name = "asp-${var.application_name}-${var.environment}"
  web-app-name      = "app-${var.application_name}-${var.environment}-${var.unique_id}"
}

resource "azurerm_service_plan" "this" {
  name                = local.app-svc-plan-name
  resource_group_name = var.resource_group
  location            = var.location
  sku_name            = var.service_plan_options.sku_name
  os_type             = var.service_plan_options.os_type
}

module "windows_web_app" {
  count = var.service_plan_options.os_type == "Windows" ? 1 : 0

  source = "./windows-web-app"

  resource_group     = var.resource_group
  web_app_name       = local.web-app-name
  environment        = var.environment
  location           = var.location
  unique_id          = var.unique_id
  service_plan_id    = azurerm_service_plan.this.id
  appsvc_subnet_id   = var.appsvc_subnet_id
  frontend_subnet_id = var.frontend_subnet_id
  webapp_options     = var.webapp_options
  private_dns_zone   = var.private_dns_zone
}

module "linux_web_app" {
  count = var.service_plan_options.os_type == "Linux" ? 1 : 0

  source = "./windows-web-app"

  resource_group     = var.resource_group
  web_app_name       = local.web-app-name
  environment        = var.environment
  location           = var.location
  unique_id          = var.unique_id
  service_plan_id    = azurerm_service_plan.this.id
  appsvc_subnet_id   = var.appsvc_subnet_id
  frontend_subnet_id = var.frontend_subnet_id
  webapp_options     = var.webapp_options
  private_dns_zone   = var.private_dns_zone
}