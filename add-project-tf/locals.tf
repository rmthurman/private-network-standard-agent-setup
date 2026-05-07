# Resolve optional subscription IDs to the account subscription when not overridden
locals {
  cosmosdb_subscription_id  = var.cosmosdb_subscription_id  != "" ? var.cosmosdb_subscription_id  : var.account_subscription_id
  storage_subscription_id   = var.storage_subscription_id   != "" ? var.storage_subscription_id   : var.account_subscription_id
  ai_search_subscription_id = var.ai_search_subscription_id != "" ? var.ai_search_subscription_id : var.account_subscription_id
}

# Fully-qualified resource IDs for BYO resources (avoids data source lookups across subscriptions)
locals {
  account_id   = "/subscriptions/${var.account_subscription_id}/resourceGroups/${var.account_resource_group}/providers/Microsoft.CognitiveServices/accounts/${var.existing_account_name}"
  cosmosdb_id  = "/subscriptions/${local.cosmosdb_subscription_id}/resourceGroups/${var.cosmosdb_resource_group}/providers/Microsoft.DocumentDB/databaseAccounts/${var.existing_cosmosdb_name}"
  storage_id   = "/subscriptions/${local.storage_subscription_id}/resourceGroups/${var.storage_resource_group}/providers/Microsoft.Storage/storageAccounts/${var.existing_storage_name}"
  ai_search_id = "/subscriptions/${local.ai_search_subscription_id}/resourceGroups/${var.ai_search_resource_group}/providers/Microsoft.Search/searchServices/${var.existing_ai_search_name}"
}

# Connection names — scoped to the project, named for clarity
locals {
  cosmosdb_conn_name  = var.existing_cosmosdb_name
  storage_conn_name   = var.existing_storage_name
  ai_search_conn_name = var.existing_ai_search_name
}

# Project workspace GUID derived from the internalId property.
# Used to scope the Storage Blob Data Owner ABAC condition to project-specific containers.
locals {
  project_id_guid = "${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 20, 12)}"
}
