# ─── Existing AI Foundry account ───────────────────────────────────────────

variable "existing_account_name" {
  description = "Name of the existing AI Foundry (CognitiveServices) account to add the project to"
  type        = string
}

variable "account_resource_group" {
  description = "Resource group name containing the existing AI Foundry account"
  type        = string
}

variable "account_subscription_id" {
  description = "Subscription ID containing the existing AI Foundry account"
  type        = string
}

# ─── New project settings ───────────────────────────────────────────────────

variable "project_name" {
  description = "Name for the new AI Foundry project (must be unique within the account)"
  type        = string
}

variable "project_display_name" {
  description = "Display name for the new project"
  type        = string
}

variable "project_description" {
  description = "Description for the new project"
  type        = string
  default     = "AI Foundry project with network-secured Agent capability host"
}

variable "project_cap_host_name" {
  description = "Name for the project-level capability host resource"
  type        = string
  default     = "caphostproj"
}

variable "location" {
  description = "Azure region for the project. Must match the region of the existing AI Foundry account"
  type        = string
}

# ─── Existing Cosmos DB (BYO thread storage) ────────────────────────────────

variable "existing_cosmosdb_name" {
  description = "Name of the existing Cosmos DB account to use for agent thread storage"
  type        = string
}

variable "cosmosdb_resource_group" {
  description = "Resource group name containing the existing Cosmos DB account"
  type        = string
}

variable "cosmosdb_subscription_id" {
  description = "Subscription ID containing the existing Cosmos DB account (defaults to account_subscription_id)"
  type        = string
  default     = ""
}

# ─── Existing Storage Account (BYO file storage) ────────────────────────────

variable "existing_storage_name" {
  description = "Name of the existing Storage account to use for agent file storage"
  type        = string
}

variable "storage_resource_group" {
  description = "Resource group name containing the existing Storage account"
  type        = string
}

variable "storage_subscription_id" {
  description = "Subscription ID containing the existing Storage account (defaults to account_subscription_id)"
  type        = string
  default     = ""
}

# ─── Existing AI Search (BYO vector store) ──────────────────────────────────

variable "existing_ai_search_name" {
  description = "Name of the existing Azure AI Search service to use as the vector store"
  type        = string
}

variable "ai_search_resource_group" {
  description = "Resource group name containing the existing AI Search service"
  type        = string
}

variable "ai_search_subscription_id" {
  description = "Subscription ID containing the existing AI Search service (defaults to account_subscription_id)"
  type        = string
  default     = ""
}
