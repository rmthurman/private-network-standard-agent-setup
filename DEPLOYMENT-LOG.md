# Foundry Private Endpoints - Deployment Log

**Date:** April 21, 2026
**Region:** westus3
**Resource Group:** `rg-foundry-pe-westus3`
**Source Template:** [microsoft-foundry/foundry-samples - 15-private-network-standard-agent-setup](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)

---

## Environment Setup

- **Subscription:** `ME-MngEnvMCAP945211-rathur-1` (`5834bd7f-f5ad-42c9-8923-48c60bcbef69`)
- **Hub VNet:** `vnet-westus3-hub` (10.0.0.0/22) in `rg-hub-spoke-westus3` — has VPN gateway `vpn-gateway-westus3`
- **Spoke VNet (used):** `vnet-westus3-spoke-two` (10.200.0.0/22 + 10.200.4.0/24), peered to hub
- **Agent Subnet:** `snet-foundry-agent-v2` (10.200.4.0/24, Microsoft.App/environments delegation) — original `snet-foundry-agent` (10.200.2.0/24) is stuck with orphaned serviceAssociationLink
- **PE Subnet:** `snet-foundry-pe` (10.200.3.0/24)
- **Existing DNS Zones reused:** `privatelink.search.windows.net`, `privatelink.blob.core.windows.net` (both in `rg-hub-spoke-westus3`)
- **DNS Zones created:** `privatelink.services.ai.azure.com`, `privatelink.openai.azure.com`, `privatelink.cognitiveservices.azure.com`, `privatelink.documents.azure.com`

---

## Deployment Attempts & Lessons Learned

### Attempt 1 — Suffix `cqlt` — FAILED

**Parameters:** `aiServices = 'foundry-pe'`, `modelName = 'gpt-4.1'`, `modelVersion = '2025-04-14'`, `modelSkuName = 'GlobalStandard'`

**Failures:**

1. **Storage account name invalid** — The template generates storage names as `{aiServices}{suffix}storage`. With `aiServices = 'foundry-pe'`, this produced `foundry-pecqltstorage` which contains a hyphen. Azure Storage account names must be 3-24 chars, lowercase alphanumeric only.
   - **Fix:** Changed `aiServices` param from `'foundry-pe'` to `'foundrype'`.

2. **Concurrent subnet operation conflict (`AnotherOperationInProgress`)** — The `existing-vnet.bicep` module creates both `snet-foundry-agent` and `snet-foundry-pe` subnets in parallel against the same VNet. Azure VNet only allows one subnet operation at a time.
   - **Fix:** Added `dependsOn: [agentSubnet]` to the PE subnet module in `existing-vnet.bicep` to serialize subnet creation.
   - **Additional fix:** Pre-created both subnets via CLI before deploying, so the template uses `existing` mode instead of creating them.

**Orphaned resources created:** `foundry-pecqltcosmosdb`, `foundry-pecqltsearch` — both manually deleted.

---

### Attempt 2 — Suffix `f4ax` — FAILED

**Parameters:** `aiServices = 'foundrype'`, `modelName = 'gpt-4.1'`, `modelVersion = '2025-04-14'`, `modelSkuName = 'GlobalStandard'`

**What worked:**
- Storage name now valid (`foundrypef4axstorage`)
- Subnets created without conflict (serialized + pre-created)
- All three dependencies provisioned successfully: Storage (~22s), CosmosDB (~2min), Search (~10min)

**Failure:**

3. **Insufficient quota for gpt-4.1 GlobalStandard** — The AI Account deployment (`foundrypef4ax-f4ax-deployment`) failed with:
   > `InsufficientQuota: This operation require 30 new capacity in quota Tokens Per Minute (thousands) - 4.1 - GlobalStandard, which is bigger than the current available capacity 0. The current quota usage is 1000 and the quota limit is 1000.`
   - Quota for `OpenAI.GlobalStandard.gpt4.1` was fully consumed (1000/1000).
   - **Fix:** Switched model to `gpt-4o` which had 225/450 available.

**Orphaned resources created:** `foundrypef4axstorage`, `foundrypef4axsearch`, `foundrypef4axcosmosdb` — all manually deleted.

---

### Attempt 3 — Suffix `sqxk` — FAILED (cancelled)

**Parameters:** `aiServices = 'foundrype'`, `modelName = 'gpt-4o'`, `modelVersion = '2024-08-06'`, `modelSkuName = 'GlobalStandard'`

**Failure:**

4. **Model version deprecating** — The AI Account deployment failed with:
   > `ServiceModelDeprecating: The model 'Format:OpenAI,Name:gpt-4o,Version:2024-08-06' is in deprecating state and cannot be used for new deployments.`
   - **Fix:** Changed model version to `'2024-11-20'` (latest available).

**Key insight:** Each deployment generates a new `uniqueString` suffix, creating entirely new dependency resources (Search, CosmosDB, Storage). This wastes time (~10-15 min for Search alone) and leaves orphans on failure.

**Action taken:** Cancelled the deployment, then pointed params at the existing `sqxk` dependency resources to avoid recreating them.

**Orphaned resources:** The `sqxk` dependencies were kept and reused in attempt 4.

---

### Attempt 4 — Suffix `rejk` — PARTIAL SUCCESS

**Parameters:** `aiServices = 'foundrype'`, `modelName = 'gpt-4o'`, `modelVersion = '2024-11-20'`, reusing `sqxk` dependencies.

**What worked:** AI account, PE, DNS, project, RBAC all succeeded. Created VNet links for all 4 DNS zones linked to `vnet-westus3-spoke-two`.

**What was left behind:** The `rejk` AI account + project + private endpoints + DNS VNet links all succeeded. These became orphans for later attempts.

---

### Attempt 5 — Suffix `4ysm` — FAILED

**Failure:**

5. **Search capacity exhausted in westus3** — Standard SKU Search failed to provision in westus3 with: `ServiceNotAvailable`. Attempted Basic SKU — also failed. **westus3 has zero Search capacity for any SKU.**
   - **Fix:** Created AI Search (`foundrypesearch`, basic SKU) in **eastus** instead, and passed its resource ID via `aiSearchResourceId`.

6. **Subnet locked by orphaned capability host** — `snet-foundry-agent` (10.200.2.0/24) had `Microsoft.App/environments` delegation + a `serviceAssociationLink` (`legionservicelink`) from the `rejk` attempt's capability host. This link:
   - Prevents removing the delegation
   - Prevents deleting the subnet
   - Can only be removed by the owning service (Container Apps) — not by the user
   - Deleting and purging the AI account (`foundrype4ysm`) did NOT release it
   - **Fix:** Expanded `vnet-westus3-spoke-two` address space by adding `10.200.4.0/24`, created new subnet `snet-foundry-agent-v2` (10.200.4.0/24), updated VNet peering, and pointed `agentSubnetName` to `snet-foundry-agent-v2`.

**Key insight:** Once a capability host creates a Container Apps environment on a subnet, that subnet's `serviceAssociationLink` persists even after deleting the AI account. The old subnet becomes permanently unusable without an Azure support ticket.

---

### Attempt 6 — Suffix `4cey` — FAILED (partial success)

**Parameters:** Same as attempt 5 but with `agentSubnetName = 'snet-foundry-agent-v2'`, `agentSubnetPrefix = '10.200.4.0/24'`, Search in eastus.

**What worked:**
- AI Account `foundrype4cey` created successfully on new clean subnet
- Capability host + Container Apps environment deployed on `snet-foundry-agent-v2`
- All dependencies reused correctly

**Failure:**

7. **DNS zone VNet link conflict** — The private endpoint module tried to create VNet links (e.g., `aiServices-4cey-link`) on the 4 DNS zones in `rg-foundry-pe-westus3`. But those zones already had VNet links (`*-rejk-link`) from attempt 4's `rejk` deployment, linking to the same VNet. Azure only allows one VNet link per VNet per DNS zone.
   - **Fix:** Manually deleted all 4 stale `rejk` VNet links:
     - `aiservices-rejk-link` from `privatelink.services.ai.azure.com`
     - `aiservicescognitiveservices-rejk-link` from `privatelink.cognitiveservices.azure.com`
     - `aiservicesopenai-rejk-link` from `privatelink.openai.azure.com`
     - `cosmosdb-rejk-link` from `privatelink.documents.azure.com`

---

### Attempt 7 — Suffix `2qtq` — FAILED

**Issue:** Redeploying after deleting the stale VNet links generated a **new suffix** (`2qtq`) because `uniqueString()` uses `utcNow()`. This created a new AI account `foundrype2qtq` which tried to create a capability host on `snet-foundry-agent-v2` — but that subnet was already in use by `foundrype4cey`'s capability host from attempt 6.

**Error:** `The subnet '...snet-foundry-agent-v2' is already in use. The subnet must not already be in use by any other environment or Azure service.`

**Fix:** Added a `fixedSuffix` parameter to `main.bicep` to allow reusing an existing suffix:
```bicep
@description('Optional fixed suffix to reuse existing resources. Leave empty to generate a new unique suffix.')
param fixedSuffix string = ''
var uniqueSuffix = !empty(fixedSuffix) ? fixedSuffix : substring(uniqueString('${resourceGroup().id}-${deploymentTimestamp}'), 0, 4)
```

Set `fixedSuffix = '4cey'` in `main.bicepparam` to reuse the existing AI account. Deleted and purged the failed `foundrype2qtq` account.

---

### Attempt 8 — Suffix `4cey` (fixed) — **SUCCEEDED**

**What happened:** With `fixedSuffix = '4cey'`, the template reused the existing AI account `foundrype4cey` and its capability host. The private endpoint module initially showed as "Failed" (cached ARM state from attempt 6), but the VNet links were actually created successfully. The deployment continued through all remaining steps:

- [x] VNet + Subnet validation — Succeeded
- [x] Dependencies validation — Succeeded (reusing existing)
- [x] AI Account `foundrype4cey` — Succeeded (already existed)
- [x] Private endpoints + DNS VNet links — Succeeded (links created after rejk cleanup)
- [x] Project `agent-project4cey` — Succeeded
- [x] RBAC role assignments (Storage, CosmosDB, Search) — Succeeded
- [x] Capability host configuration (`caphostproj`) — Succeeded
- [x] Container RBAC (Storage blob, CosmosDB containers) — Succeeded

**Final deployment time:** ~15 min for attempt 8 (most time spent on capability host configuration)

---

## Key Lessons Learned

### Template Behavior
1. **`uniqueString()` suffix changes every deployment** — The template uses `utcNow()` in the uniqueString seed, so each deployment generates a different suffix. This means failed deployments leave orphaned resources (AI accounts, private endpoints, DNS records) that must be cleaned up manually.
2. **Reuse existing resources on retry** — Pass resource IDs via `aiSearchResourceId`, `azureStorageAccountResourceId`, `azureCosmosDBAccountResourceId` params to skip creating new dependencies. This saves ~15 min per retry.
3. **Subnet operations are serialized by Azure** — Always add `dependsOn` between subnet modules targeting the same VNet, or pre-create subnets via CLI.
4. **Add a `fixedSuffix` parameter** — Critical for retries. Without it, each redeploy creates a new AI account that tries to use the same subnet, which fails because the subnet is already occupied by the previous attempt's capability host. The fix: add a `fixedSuffix` param that overrides `uniqueString()` so you can reuse an existing AI account.
5. **ARM caches deployment results** — When re-running with the same deployment name (e.g., `4cey-private-endpoint`), ARM may show a cached "Failed" status from a previous run even though the resources were actually created. The deployment can still proceed past this.

### DNS & Private Endpoints
6. **One VNet link per VNet per DNS zone** — A private DNS zone can only be linked to a given VNet once. If a prior deployment created a VNet link and then failed, you must delete the stale link before redeploying.
7. **Stale VNet links are the #1 redeploy killer** — Failed deployments leave `*-link` resources in DNS zones. Always check and clean these before retrying.

### Subnet & Capability Host
8. **Capability host locks the subnet permanently** — Once a Container Apps environment is created via the capability host, the subnet gets a `serviceAssociationLink` (`legionservicelink`) that persists even after deleting the AI account. The subnet becomes permanently unusable without an Azure support ticket.
9. **Workaround for locked subnets** — Expand the VNet address space and create a new subnet. Update peering if necessary.

### Naming & Validation
10. **Storage account names** — No hyphens, no uppercase, 3-24 chars. The `aiServices` param feeds into storage naming, so keep it alphanumeric lowercase.
11. **Model versions deprecate** — Always check `az cognitiveservices model list --location <region>` for the latest available version before deploying.

### Quota & Regional Capacity
12. **Check quota before deploying** — Use `az cognitiveservices usage list --location <region>` to verify available capacity.
13. **gpt-4.1 GlobalStandard** was fully consumed in westus3 (1000/1000). Switched to gpt-4o (225/450 available).
14. **Azure AI Search has region-specific capacity limits** — westus3 had ZERO capacity for both Standard and Basic SKUs. Had to create Search in eastus instead. Always verify Search capacity in your target region first.

### Timing
15. **Azure Search (Standard SKU)** takes 10-15 min to provision — the single slowest resource.
16. **CosmosDB** takes ~2 min to provision.
17. **CosmosDB private endpoints** take ~5-8 min (slower than other PE types).
18. **RBAC role assignments on Search** can take 3-5+ min.
19. **AI Services account** takes ~3-4 min to create.
20. **Capability host configuration** takes ~10 min (creates Container Apps environment).

### Cost Considerations
- Skipped Bastion Host deployment (expensive). Using existing VPN gateway in `vnet-westus3-hub` for private access.
- Search Standard SKU is a significant ongoing cost — consider Basic SKU for non-production.
- Search Basic SKU was used and deployed to eastus (cross-region, but functional).

---

## Final Deployed Resources

| Resource | Name | Location | Notes |
|---|---|---|---|
| AI Account | `foundrype4cey` | westus3 | Network: Deny (PE only) |
| Project | `agent-project4cey` | westus3 | Sub-resource of AI account |
| Model | `gpt-4o` (2024-11-20) | GlobalStandard | 30K TPM capacity |
| Storage | `foundrypesqxkstorage` | westus3 | Reused from attempt 3 |
| CosmosDB | `foundrypesqxkcosmosdb` | westus3 | Reused from attempt 3 |
| AI Search | `foundrypesearch` | **eastus** | Basic SKU (westus3 had no capacity) |
| PE (AI Services) | `foundrype4cey-private-endpoint` | 10.200.3.12-14 | Approved |
| PE (Search) | `foundrypesearch-private-endpoint` | snet-foundry-pe | Approved |
| PE (Storage) | `foundrypesqxkstorage-private-endpoint` | snet-foundry-pe | Approved |
| PE (CosmosDB) | `foundrypesqxkcosmosdb-private-endpoint` | snet-foundry-pe | Approved |
| Capability Host | `foundrype4cey@aml_aiagentservice` | snet-foundry-agent-v2 | Container Apps env |

---

## Resource Naming Convention

| Resource | Name Pattern | Example |
|---|---|---|
| Resource Group | `rg-{purpose}-{region}` | `rg-foundry-pe-westus3` |
| VNet | `vnet-{region}-{role}` | `vnet-westus3-spoke-two` |
| Subnet | `snet-{purpose}` | `snet-foundry-agent`, `snet-foundry-pe` |
| AI Services | `{prefix}{suffix}` | `foundryperejk` |
| Storage | `{prefix}{suffix}storage` | `foundrypesqxkstorage` |
| Search | `{prefix}{suffix}search` | `foundrypesqxksearch` |
| CosmosDB | `{prefix}{suffix}cosmosdb` | `foundrypesqxkcosmosdb` |
| Private Endpoint | `{resourceName}-private-endpoint` | `foundryperejk-private-endpoint` |

---

## Files Modified from Original Sample

1. **`main.bicepparam`** — Fully customized for this environment (region, VNet, DNS zones, model, existing resource IDs, `fixedSuffix`)
2. **`modules-network-secured/existing-vnet.bicep`** — Added `dependsOn: [agentSubnet]` to PE subnet module to fix concurrent subnet race condition
3. **`main.bicep`** — Added `fixedSuffix` parameter to allow reusing existing resources on retry (prevents new suffix generation)
4. **`modules-network-secured/standard-dependent-resources.bicep`** — Changed default Search SKU from `'standard'` to `'basic'`

## Known Issues / Cleanup Needed

- **Orphaned subnet `snet-foundry-agent`** (10.200.2.0/24) — Stuck with `Microsoft.App/environments` delegation and `legionservicelink` service association link. Cannot be deleted without Azure support ticket.
- **Orphaned resources from attempt 4 (`rejk`)** — `foundryperejk` AI account and its private endpoint still exist. The project `agent-projectrejk` is also present. These should be deleted and purged.
- **Orphaned DNS A records** — `foundryperejk` records exist in the DNS zones from the old PE. These are harmless but untidy.
- **`foundrypesqxksearch-private-endpoint`** — Shows `Disconnected` status (orphan from earlier attempt). Should be deleted.
