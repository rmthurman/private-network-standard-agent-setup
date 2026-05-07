# ─── Existing AI Foundry account ────────────────────────────────────────────
existing_account_name   = "foundryperejk"
account_resource_group  = "rg-foundry-pe-westus3"
account_subscription_id = "5834bd7f-f5ad-42c9-8923-48c60bcbef69"

# ─── New project settings ────────────────────────────────────────────────────
# Update these two values for your new project before running terraform apply
project_name          = "agent-project2"           # must be unique within the account
project_display_name  = "Agent Project 2"
project_description   = "AI Foundry project with network-secured Agent capability host"
project_cap_host_name = "caphostproj2"

# Must match the AI Foundry account region
location = "westus3"

# ─── BYO Cosmos DB (thread storage) ─────────────────────────────────────────
existing_cosmosdb_name  = "foundrypesqxkcosmosdb"
cosmosdb_resource_group = "rg-foundry-pe-westus3"
# cosmosdb_subscription_id defaults to account_subscription_id

# ─── BYO Storage Account (file storage) ─────────────────────────────────────
existing_storage_name  = "foundrypesqxkstorage"
storage_resource_group = "rg-foundry-pe-westus3"
# storage_subscription_id defaults to account_subscription_id

# ─── BYO AI Search (vector store) ────────────────────────────────────────────
# Note: foundrypesearch is in eastus — cross-region BYO is supported
existing_ai_search_name  = "foundrypesearch"
ai_search_resource_group = "rg-foundry-pe-westus3"
# ai_search_subscription_id defaults to account_subscription_id
