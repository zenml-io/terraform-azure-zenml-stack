output "abc_service_connector" {
  description = "The Azure Blob Container service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.abc
}

output "acr_service_connector" {
  description = "The Azure Container Registry service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.acr
}

output "azure_service_connector" {
  description = "The generic Azure service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.azure
}

output "artifact_store" {
  description = "The artifact store that was registered with the ZenML server"
  value = data.zenml_stack_component.artifact_store
}

output "container_registry" {
  description = "The container registry that was registered with the ZenML server"
  value = data.zenml_stack_component.container_registry
}

output "orchestrator" {
  description = "The orchestrator that was registered with the ZenML server"
  value = data.zenml_stack_component.orchestrator
}

output "step_operator" {
  description = "The step operator that was registered with the ZenML server"
  value = data.zenml_stack_component.step_operator
}

output "image_builder" {
  description = "The image builder that was registered with the ZenML server"
  value = data.zenml_stack_component.image_builder
}

output "zenml_stack" {
  description = "The ZenML stack that was registered with the ZenML server"
  value = data.zenml_stack.stack
}

output "zenml_stack_id" {
  description = "The ID of the ZenML stack that was registered with the ZenML server"
  value = zenml_stack.stack.id
}

output "zenml_stack_name" {
  description = "The name of the ZenML stack that was registered with the ZenML server"
  value = zenml_stack.stack.name
}