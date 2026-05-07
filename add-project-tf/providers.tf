# Default providers (used when no explicit alias is specified)
provider "azapi" {}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

# Workload subscription providers — all project resources are deployed here
provider "azapi" {
  alias           = "workload_subscription"
  subscription_id = var.account_subscription_id
}

provider "azurerm" {
  alias               = "workload_subscription"
  subscription_id     = var.account_subscription_id
  features {}
  storage_use_azuread = true
}
