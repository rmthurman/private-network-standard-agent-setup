using './add-project.bicep'

param location = 'westus3'

// New project details
param projectName = 'secondproject'
param projectDescription = 'Second AI Foundry project with network secured deployed Agent'
param displayName = 'Second Project'
param projectCapHost = 'caphostsecond'

// Existing AI Services account (foundrype4cey in rg-foundry-pe-westus3)
param existingAccountName = 'foundrype4cey'
param accountResourceGroupName = 'rg-foundry-pe-westus3'
param accountSubscriptionId = '5834bd7f-f5ad-42c9-8923-48c60bcbef69'

// Existing shared resources (all from original sqxk/4cey deployment)
param existingAiSearchName = 'foundrypesearch'
param aiSearchResourceGroupName = 'rg-foundry-pe-westus3'
param aiSearchSubscriptionId = '5834bd7f-f5ad-42c9-8923-48c60bcbef69'

param existingStorageName = 'foundrypesqxkstorage'
param storageResourceGroupName = 'rg-foundry-pe-westus3'
param storageSubscriptionId = '5834bd7f-f5ad-42c9-8923-48c60bcbef69'

param existingCosmosDBName = 'foundrypesqxkcosmosdb'
param cosmosDBResourceGroupName = 'rg-foundry-pe-westus3'
param cosmosDBSubscriptionId = '5834bd7f-f5ad-42c9-8923-48c60bcbef69'
