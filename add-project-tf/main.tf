########## Create AI Foundry project ##########

## Create the project under the existing AI Foundry account.
## System-assigned managed identity is enabled so role assignments
## can be scoped to this specific project identity.
resource "azapi_resource" "ai_foundry_project" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = var.project_name
  parent_id                 = local.account_id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName = var.project_display_name
      description = var.project_description
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.internalId"
  ]
}

## Give the system-assigned managed identity time to replicate through Entra ID
## before role assignments are attempted against it.
resource "time_sleep" "wait_project_identity" {
  depends_on      = [azapi_resource.ai_foundry_project]
  create_duration = "10s"
}

########## Project connections ##########
## Each connection links the project to a BYO resource so that the
## capability host can reference them by name.

resource "azapi_resource" "conn_cosmosdb" {
  provider = azapi.workload_subscription

  depends_on = [azapi_resource.ai_foundry_project]

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name                      = local.cosmosdb_conn_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      category = "CosmosDB"
      target   = "https://${var.existing_cosmosdb_name}.documents.azure.com:443/"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = local.cosmosdb_id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "conn_storage" {
  provider = azapi.workload_subscription

  depends_on = [azapi_resource.ai_foundry_project]

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name                      = local.storage_conn_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = "https://${var.existing_storage_name}.blob.core.windows.net/"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = local.storage_id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "conn_aisearch" {
  provider = azapi.workload_subscription

  depends_on = [azapi_resource.ai_foundry_project]

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name                      = local.ai_search_conn_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${var.existing_ai_search_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = local.ai_search_id
        location   = var.location
      }
    }
  }
}

########## Pre-capability-host role assignments ##########
## These control-plane roles must exist before the capability host
## can be created; the 60-second wait allows them to propagate.

resource "azurerm_role_assignment" "cosmosdb_operator" {
  provider = azurerm.workload_subscription

  depends_on = [time_sleep.wait_project_identity]

  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.existing_cosmosdb_name}cosmosdboperator")
  scope                = local.cosmosdb_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  provider = azurerm.workload_subscription

  depends_on = [time_sleep.wait_project_identity]

  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.existing_storage_name}storageblobdatacontributor")
  scope                = local.storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_index_data_contributor" {
  provider = azurerm.workload_subscription

  depends_on = [time_sleep.wait_project_identity]

  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.existing_ai_search_name}searchindexdatacontributor")
  scope                = local.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_service_contributor" {
  provider = azurerm.workload_subscription

  depends_on = [time_sleep.wait_project_identity]

  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.existing_ai_search_name}searchservicecontributor")
  scope                = local.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

## Allow RBAC to propagate before creating the capability host
resource "time_sleep" "wait_rbac" {
  depends_on = [
    azurerm_role_assignment.cosmosdb_operator,
    azurerm_role_assignment.storage_blob_data_contributor,
    azurerm_role_assignment.search_index_data_contributor,
    azurerm_role_assignment.search_service_contributor,
  ]
  create_duration = "60s"
}

########## Project capability host ##########
## Wires the project to its BYO resources so that agents created
## inside this project can use them for threads, files, and search.

resource "azapi_resource" "ai_foundry_project_capability_host" {
  provider = azapi.workload_subscription

  depends_on = [
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    azapi_resource.conn_aisearch,
    time_sleep.wait_rbac,
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = var.project_cap_host_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind       = "Agents"
      vectorStoreConnections   = [local.ai_search_conn_name]
      storageConnections       = [local.storage_conn_name]
      threadStorageConnections = [local.cosmosdb_conn_name]
    }
  }
}

########## Post-capability-host role assignments ##########
## The capability host creation provisions containers and databases
## in the BYO resources; these data-plane roles must be assigned after.

## Cosmos DB Built-in Data Contributor — scoped to the enterprise_memory
## database that the capability host creates for agent thread storage.
## Using azapi_resource here supports cross-subscription deployments.
resource "azapi_resource" "cosmosdb_sql_role_assignment" {
  provider = azapi.workload_subscription

  depends_on = [azapi_resource.ai_foundry_project_capability_host]

  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15"
  name      = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}cosmosdb_dbsqlrole")
  parent_id = local.cosmosdb_id
  schema_validation_enabled = false

  body = {
    properties = {
      principalId      = azapi_resource.ai_foundry_project.output.identity.principalId
      roleDefinitionId = "${local.cosmosdb_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
      scope            = "${local.cosmosdb_id}/dbs/enterprise_memory"
    }
  }
}

## Storage Blob Data Owner — restricted via ABAC condition to only the
## project-specific containers (<workspaceId>-*-azureml-agent) that the
## capability host provisions.  This avoids granting blanket Data Owner
## across the entire storage account.
resource "azurerm_role_assignment" "storage_blob_data_owner" {
  provider = azurerm.workload_subscription

  depends_on = [azapi_resource.ai_foundry_project_capability_host]

  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.existing_storage_name}storageblobdataowner")
  scope                = local.storage_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
  condition_version    = "2.0"
  condition            = <<-EOT
  (
    (
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})
      AND
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'})
      AND
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'})
    )
    OR
    (
      @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name]
      StringStartsWithIgnoreCase '${local.project_id_guid}'
      AND
      @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name]
      StringLikeIgnoreCase '*-azureml-agent'
    )
  )
  EOT
}
