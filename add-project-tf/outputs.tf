output "project_name" {
  description = "Name of the newly created AI Foundry project"
  value       = azapi_resource.ai_foundry_project.name
}

output "project_id" {
  description = "Full ARM resource ID of the project"
  value       = azapi_resource.ai_foundry_project.id
}

output "project_principal_id" {
  description = "Object (principal) ID of the project's system-assigned managed identity"
  value       = azapi_resource.ai_foundry_project.output.identity.principalId
}

output "project_workspace_id" {
  description = "Internal workspace ID (internalId) of the project — used for container scoping"
  value       = azapi_resource.ai_foundry_project.output.properties.internalId
}

output "project_workspace_id_guid" {
  description = "Project workspace ID formatted as a standard GUID"
  value       = local.project_id_guid
}

output "capability_host_name" {
  description = "Name of the project capability host resource"
  value       = azapi_resource.ai_foundry_project_capability_host.name
}

output "capability_host_id" {
  description = "Full ARM resource ID of the project capability host"
  value       = azapi_resource.ai_foundry_project_capability_host.id
}
