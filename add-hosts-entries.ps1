$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$entries = @"

# Foundry Private Endpoints - westus3 (foundrype4cey)
10.200.3.14    foundrype4cey.services.ai.azure.com foundrype4cey.privatelink.services.ai.azure.com
10.200.3.13    foundrype4cey.openai.azure.com foundrype4cey.privatelink.openai.azure.com
10.200.3.12    foundrype4cey.cognitiveservices.azure.com foundrype4cey.privatelink.cognitiveservices.azure.com
10.200.3.10    foundrypesqxkstorage.blob.core.windows.net foundrypesqxkstorage.privatelink.blob.core.windows.net
10.200.3.4     foundrypesqxkcosmosdb.documents.azure.com foundrypesqxkcosmosdb.privatelink.documents.azure.com
10.200.3.11    foundrypesearch.search.windows.net foundrypesearch.privatelink.search.windows.net

# Foundry Private Endpoints - westus3 (foundryperejk)
10.200.3.8     foundryperejk.services.ai.azure.com foundryperejk.privatelink.services.ai.azure.com
10.200.3.7     foundryperejk.openai.azure.com foundryperejk.privatelink.openai.azure.com
10.200.3.6     foundryperejk.cognitiveservices.azure.com foundryperejk.privatelink.cognitiveservices.azure.com
"@

Add-Content -Path $hostsFile -Value $entries
Clear-DnsClientCache
Write-Host "Done. Verifying..."
Get-Content $hostsFile | Select-String "foundrype|foundrypesqxk|foundrypesearch"
