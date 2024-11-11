variable "location" {
  description = "The Azure region where resources will be created"
  # Make a choice from the list of Azure regions
  type        = string
  default     = "westus"
}

variable "orchestrator" {
  description = "The orchestrator to be used, either 'skypilot', 'azureml' or 'local'."
  type        = string
  default     = "azureml"

  validation {
    condition     = contains(["skypilot", "azureml", "local"], var.orchestrator)
    error_message = "If set, the orchestrator must be either 'skypilot', 'azureml' or 'local'."
  }
}

variable "zenml_stack_name" {
  description = "A custom name for the ZenML stack that will be registered with the ZenML server"
  type        = string
  default     = ""
}

variable "zenml_stack_deployment" {
  description = "The deployment type for the ZenML stack. Used as a label for the registered ZenML stack."
  type        = string
  default     = "terraform"
}

variable "storage_account_tier" {
  description = "The tier for the Azure storage account"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "The replication type for the Azure storage account"
  type        = string
  default     = "LRS"
}

variable "container_registry_sku" {
  description = "The SKU for the Azure container registry"
  type        = string
  default     = "Basic"
}

variable "azureml_workspace_sku" {
  description = "The SKU for the Azure Machine Learning workspace"
  type        = string
  default     = "Basic"
}

variable "azureml_key_value_sku" {
  description = "The SKU for the Azure Machine Learning key vault"
  type        = string
  default     = "standard"
}
