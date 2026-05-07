# ─── Copy this file to terraform.tfvars and fill in your values ─────────────

# Existing AI Foundry account
existing_account_name   = ""   # e.g. "myfoundryhub"
account_resource_group  = ""   # e.g. "my-foundry-rg"
account_subscription_id = ""   # e.g. "55555555-5555-5555-5555-555555555555"

# New project settings
project_name          = ""   # e.g. "secondproject"  (must be unique within the account)
project_display_name  = ""   # e.g. "Second Project"
project_description   = "AI Foundry project with network-secured Agent capability host"
project_cap_host_name = "caphostproj"

# Azure region — must match the existing AI Foundry account's region
location = ""   # e.g. "westus"

# Existing Cosmos DB account (BYO thread storage)
existing_cosmosdb_name  = ""   # e.g. "myfoundrycosmosdb"
cosmosdb_resource_group = ""   # e.g. "my-foundry-rg"
# cosmosdb_subscription_id = ""  # Uncomment if in a different subscription

# Existing Storage account (BYO file storage)
existing_storage_name  = ""   # e.g. "myfoundrystorage"
storage_resource_group = ""   # e.g. "my-foundry-rg"
# storage_subscription_id = ""  # Uncomment if in a different subscription

# Existing AI Search service (BYO vector store)
existing_ai_search_name  = ""   # e.g. "myfoundrysearch"
ai_search_resource_group = ""   # e.g. "my-foundry-rg"
# ai_search_subscription_id = ""  # Uncomment if in a different subscription
