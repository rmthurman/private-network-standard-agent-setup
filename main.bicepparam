using './main.bicep'

// ── Reuse existing resources from attempt 6 (suffix 4cey) ──
param fixedSuffix = '4cey'

// ── Region & AI Services ──
param location = 'westus3'
param aiServices = 'foundrype'
param modelName = 'gpt-4o'
param modelFormat = 'OpenAI'
param modelVersion = '2024-11-20'
param modelSkuName = 'GlobalStandard'
param modelCapacity = 30

// ── Project ──
param firstProjectName = 'agent-project'
param projectDescription = 'Network-secured Foundry agent project with private endpoints'
param displayName = 'Foundry PE Agent Project'

// ── Existing VNet (hub-spoke westus3, spoke-two peered to hub with VPN gateway) ──
param existingVnetResourceId = '/subscriptions/5834bd7f-f5ad-42c9-8923-48c60bcbef69/resourceGroups/rg-hub-spoke-westus3/providers/Microsoft.Network/virtualNetworks/vnet-westus3-spoke-two'
param vnetName = 'vnet-westus3-spoke-two'
param agentSubnetName = 'snet-foundry-agent-v2'
param peSubnetName = 'snet-foundry-pe'

// ── Reuse existing dependent resources from previous deployment ──
param aiSearchResourceId = '/subscriptions/5834bd7f-f5ad-42c9-8923-48c60bcbef69/resourceGroups/rg-foundry-pe-westus3/providers/Microsoft.Search/searchServices/foundrypesearch'
param azureStorageAccountResourceId = '/subscriptions/5834bd7f-f5ad-42c9-8923-48c60bcbef69/resourceGroups/rg-foundry-pe-westus3/providers/Microsoft.Storage/storageAccounts/foundrypesqxkstorage'
param azureCosmosDBAccountResourceId = '/subscriptions/5834bd7f-f5ad-42c9-8923-48c60bcbef69/resourceGroups/rg-foundry-pe-westus3/providers/Microsoft.DocumentDB/databaseAccounts/foundrypesqxkcosmosdb'

// ── DNS Zones ──
// Same subscription — reuse blob & search zones from hub-spoke RG, create the rest
param dnsZonesSubscriptionId = ''
param existingDnsZones = {
  'privatelink.services.ai.azure.com': ''                              // create new
  'privatelink.openai.azure.com': ''                                   // create new
  'privatelink.cognitiveservices.azure.com': ''                        // create new
  'privatelink.search.windows.net': 'rg-hub-spoke-westus3'            // reuse existing
  'privatelink.blob.core.windows.net': 'rg-hub-spoke-westus3'         // reuse existing
  'privatelink.documents.azure.com': ''                                // create new
}
param dnsZoneNames = [
  'privatelink.services.ai.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.search.windows.net'
  'privatelink.blob.core.windows.net'
  'privatelink.documents.azure.com'
]

// ── Subnet CIDRs (non-overlapping with existing 10.200.0.0/24 & 10.200.1.0/26) ──
param vnetAddressPrefix = ''
param agentSubnetPrefix = '10.200.4.0/24'
param peSubnetPrefix = '10.200.3.0/24'

