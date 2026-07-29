variable "location" {
  description = "The Azure region where resources will be created"
  # Make a choice from the list of Azure regions
  type    = string
  default = "westus"
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

variable "azureml_public_network_access_enabled" {
  description = "Whether public network access is enabled for the Azure Machine Learning workspace"
  type        = bool
  default     = true
}

variable "azureml_managed_network" {
  description = "Azure Machine Learning managed network and outbound rules"

  type = object({
    isolation_mode = string

    private_endpoint_rules = optional(map(object({
      service_resource_id = string
      sub_resource_target = string
      spark_enabled       = optional(bool, false)
    })), {})

    fqdn_rules = optional(map(object({
      destination_fqdn = string
    })), {})

    service_tag_rules = optional(map(object({
      service_tag = string
      protocol    = string
      port_ranges = string
    })), {})
  })
  default = null

  # Use null to disable managed networking; configured objects must select an active isolation mode.
  validation {
    condition = var.azureml_managed_network == null ? true : contains(
      ["AllowInternetOutbound", "AllowOnlyApprovedOutbound"],
      var.azureml_managed_network.isolation_mode
    )
    error_message = "isolation_mode must be either AllowInternetOutbound or AllowOnlyApprovedOutbound."
  }
}

variable "azureml_key_value_sku" {
  description = "The SKU for the Azure Machine Learning key vault"
  type        = string
  default     = "standard"
}

variable "key_vault_network_acls" {
  description = "Network access rules for the Azure Machine Learning key vault"
  type = object({
    bypass                     = string
    default_action             = string
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = null

  validation {
    condition = var.key_vault_network_acls == null ? true : (
      contains(["AzureServices", "None"], var.key_vault_network_acls.bypass)
      && contains(["Allow", "Deny"], var.key_vault_network_acls.default_action)
    )
    error_message = "bypass must be AzureServices or None, and default_action must be Allow or Deny."
  }
}
