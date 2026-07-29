terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    zenml = {
      source = "zenml-io/zenml"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "private_endpoint_service_resource_id" {
  type = string
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "zenml" {
  # server_url = <taken from the ZENML_SERVER_URL environment variable if not set here>
  # api_key = <taken from the ZENML_API_KEY environment variable if not set here>
}

module "zenml_stack" {
  source = "../"

  location         = "westus"
  orchestrator     = "azureml" # or "skypilot" or "local"
  zenml_stack_name = "azure-stack"

  azureml_managed_network = {
    isolation_mode = "AllowOnlyApprovedOutbound"
    private_endpoint_rules = {
      private-storage-blob = {
        service_resource_id = var.private_endpoint_service_resource_id
        sub_resource_target = "blob"
      }
    }
    fqdn_rules = {
      pypi = {
        destination_fqdn = "pypi.org"
      }
    }
    service_tag_rules = {
      azure-monitor = {
        service_tag = "AzureMonitor"
        protocol    = "TCP"
        port_ranges = "443"
      }
    }
  }

  key_vault_network_acls = {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
}

output "zenml_stack_id" {
  value     = module.zenml_stack.zenml_stack_id
  sensitive = true
}
output "zenml_stack_name" {
  value     = module.zenml_stack.zenml_stack_name
  sensitive = true
}
output "abc_service_connector" {
  value     = module.zenml_stack.abc_service_connector
  sensitive = true
}
output "acr_service_connector" {
  value     = module.zenml_stack.acr_service_connector
  sensitive = true
}
output "azure_service_connector" {
  value     = module.zenml_stack.azure_service_connector
  sensitive = true
}
output "artifact_store" {
  value     = module.zenml_stack.artifact_store
  sensitive = true
}
output "container_registry" {
  value     = module.zenml_stack.container_registry
  sensitive = true
}
output "orchestrator" {
  value     = module.zenml_stack.orchestrator
  sensitive = true
}
output "step_operator" {
  value     = module.zenml_stack.step_operator
  sensitive = true
}
output "image_builder" {
  value     = module.zenml_stack.image_builder
  sensitive = true
}
output "zenml_stack" {
  value = module.zenml_stack.zenml_stack
}