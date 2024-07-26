output "zenml_stack_id" {
  description = "The ID of the ZenML stack that was created"
  value = restapi_object.zenml_stack.id
}

output "zenml_stack_name" {
  description = "The name of the ZenML stack that was created"
  value = restapi_object.zenml_stack.api_data["name"]
}