terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    zenml = {
        source = "zenml-io/zenml"
    }
  }
}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
# Get current subscription details
data "azurerm_subscription" "primary" {
  # This will get the subscription ID from the provider configuration
}
data "zenml_server" "zenml_info" {}

locals {
  zenml_version = data.zenml_server.zenml_info.version
}


resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

resource "azurerm_resource_group" "resource_group" {
  name     = "zenml-${random_id.resource_name_suffix.hex}"
  location = var.location
}

resource "azurerm_storage_account" "artifact_store" {
  name                     = "zenml${random_id.resource_name_suffix.hex}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
}

resource "azurerm_storage_container" "artifact_container" {
  name                  = "zenml${random_id.resource_name_suffix.hex}"
  storage_account_name  = azurerm_storage_account.artifact_store.name
  container_access_type = "private"
}

resource "azurerm_container_registry" "container_registry" {
  name                = "zenml${random_id.resource_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku                 = var.container_registry_sku
  admin_enabled       = true
}

resource "azurerm_application_insights" "application_insights" {
  name                = "zenml-${random_id.resource_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  application_type    = "web"
}

resource "azurerm_key_vault" "key_vault" {
  name                = "zenml-${random_id.resource_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.azureml_key_value_sku
}

resource "azurerm_machine_learning_workspace" "azureml_workspace" {
  name                    = "zenml-${random_id.resource_name_suffix.hex}"
  resource_group_name     = azurerm_resource_group.resource_group.name
  location                = azurerm_resource_group.resource_group.location
  storage_account_id      = azurerm_storage_account.artifact_store.id
  container_registry_id   = azurerm_container_registry.container_registry.id
  application_insights_id = azurerm_application_insights.application_insights.id
  key_vault_id            = azurerm_key_vault.key_vault.id
  public_network_access_enabled = true
  identity {
    type = "SystemAssigned"
  }
  sku_name = var.azureml_workspace_sku
}

resource "azuread_application" "service_principal_app" {
  display_name = "zenml-${random_id.resource_name_suffix.hex}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "service_principal" {
  client_id = azuread_application.service_principal_app.client_id
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "service_principal_password" {
  service_principal_id = azuread_service_principal.service_principal.object_id
}

# Assign roles to the Service Principal

resource "azurerm_role_assignment" "storage_blob_data_contributor_role" {
  scope                = azurerm_storage_account.artifact_store.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_push_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_pull_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_contributor_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.service_principal.object_id
}

# This very permissive role is required only by Skypilot. Unfortunately, there
# is no way to reduce the scope of this role to a specific resource group yet
# (see https://github.com/skypilot-org/skypilot/issues/2962).
resource "azurerm_role_assignment" "subscription_owner_role" {
  count                = var.orchestrator == "skypilot" ? 1 : 0
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "azureml_compute_operator" {
  scope                = azurerm_machine_learning_workspace.azureml_workspace.id
  role_definition_name = "AzureML Compute Operator"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "azureml_data_scientist" {
  scope                = azurerm_machine_learning_workspace.azureml_workspace.id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azuread_service_principal.service_principal.object_id
}


locals {
  service_connector_config = {
    subscription_id = "${data.azurerm_client_config.current.subscription_id}"
    resource_group = "${azurerm_resource_group.resource_group.name}"
    storage_account = "${azurerm_storage_account.artifact_store.name}"
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    client_id = "${azuread_application.service_principal_app.client_id}"
    client_secret = "${azuread_service_principal_password.service_principal_password.value}"
  }
}

# Artifact Store Component

resource "zenml_service_connector" "abc" {
  name           = "${var.zenml_stack_name == "" ? "terraform-abc-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-abc"}"
  type           = "azure"
  auth_method    = "service-principal"
  resource_type  = "blob-container"
  resource_id    = azurerm_storage_container.artifact_container.name

  configuration = local.service_connector_config

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    azurerm_resource_group.resource_group,
    azurerm_storage_account.artifact_store,
    azurerm_storage_container.artifact_container,
    azuread_application.service_principal_app,
    azuread_service_principal.service_principal,
    azuread_service_principal_password.service_principal_password,
    azurerm_role_assignment.storage_blob_data_contributor_role,
  ]
}

resource "zenml_stack_component" "artifact_store" {
  name      = "${var.zenml_stack_name == "" ? "terraform-abc-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-abc"}"
  type      = "artifact_store"
  flavor    = "azure"

  configuration = {
    path = "az://${azurerm_storage_container.artifact_container.name}"
  }

  connector_id = zenml_service_connector.abc.id

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Container Registry Component

resource "zenml_service_connector" "acr" {
  name           = "${var.zenml_stack_name == "" ? "terraform-acr-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-acr"}"
  type           = "azure"
  auth_method    = "service-principal"
  resource_type  = "docker-registry"
  resource_id    = azurerm_container_registry.container_registry.name
  
  configuration = local.service_connector_config

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    azurerm_resource_group.resource_group,
    azurerm_container_registry.container_registry,
    azuread_application.service_principal_app,
    azuread_service_principal.service_principal,
    azuread_service_principal_password.service_principal_password,
    azurerm_role_assignment.acr_push_role,
    azurerm_role_assignment.acr_pull_role,
    azurerm_role_assignment.acr_contributor_role,
  ]
}

resource "zenml_stack_component" "container_registry" {
  name      = "${var.zenml_stack_name == "" ? "terraform-acr-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-acr"}"
  type      = "container_registry"
  flavor    = "azure"

  configuration = {
    uri = "${azurerm_container_registry.container_registry.login_server}"
  }

  connector_id = zenml_service_connector.acr.id

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Orchestrator

locals {
  # The orchestrator configuration is different depending on the orchestrator
  # chosen by the user. We use the `orchestrator` variable to determine which
  # configuration to use and construct a local variable `orchestrator_config` to
  # hold the configuration.
  orchestrator_config = {
    local = {}
    azureml = {
      subscription_id = "${data.azurerm_client_config.current.subscription_id}"
      resource_group = "${azurerm_resource_group.resource_group.name}"
      workspace = "zenml-${random_id.resource_name_suffix.hex}"
    }
    skypilot = {
      region = "${azurerm_resource_group.resource_group.location}"
    }
  }
}

resource "zenml_service_connector" "azure" {
  name           = "${var.zenml_stack_name == "" ? "terraform-azure-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-azure"}"
  type           = "azure"
  auth_method    = "service-principal"
  resource_type  = "azure-generic"

  configuration = local.service_connector_config

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    azurerm_resource_group.resource_group,
    azurerm_storage_account.artifact_store,
    azurerm_storage_container.artifact_container,
    azurerm_container_registry.container_registry,
    azurerm_machine_learning_workspace.azureml_workspace,
    azuread_application.service_principal_app,
    azuread_service_principal.service_principal,
    azuread_service_principal_password.service_principal_password,
    azurerm_role_assignment.storage_blob_data_contributor_role,
    azurerm_role_assignment.acr_push_role,
    azurerm_role_assignment.acr_pull_role,
    azurerm_role_assignment.acr_contributor_role,
    azurerm_role_assignment.subscription_owner_role[0],
    azurerm_role_assignment.azureml_compute_operator,
    azurerm_role_assignment.azureml_data_scientist,
  ]
}

resource "zenml_stack_component" "orchestrator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-${var.orchestrator}-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-${var.orchestrator}"}"
  type      = "orchestrator"
  flavor    = var.orchestrator == "skypilot" ? "vm_azure" : var.orchestrator

  configuration = local.orchestrator_config[var.orchestrator]

  connector_id = var.orchestrator == "local" ? "" : zenml_service_connector.azure.id

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Step Operator
resource "zenml_stack_component" "step_operator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-azureml-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-azureml"}"
  type      = "step_operator"
  flavor    = "azureml"

  configuration = {
    subscription_id = "${data.azurerm_client_config.current.subscription_id}"
    resource_group = "${azurerm_resource_group.resource_group.name}"
    workspace_name = "${azurerm_machine_learning_workspace.azureml_workspace.name}"
  }

  connector_id = zenml_service_connector.azure.id

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Image Builder
resource "zenml_stack_component" "image_builder" {
  name      = "${var.zenml_stack_name == "" ? "terraform-local-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-local"}"
  type      = "image_builder"
  flavor    = "local"

  configuration = {}

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Complete Stack
resource "zenml_stack" "stack" {
  name = "${var.zenml_stack_name == "" ? "terraform-azure-${random_id.resource_name_suffix.hex}" : var.zenml_stack_name}"

  components = {
    artifact_store     = zenml_stack_component.artifact_store.id
    container_registry = zenml_stack_component.container_registry.id
    orchestrator      = zenml_stack_component.orchestrator.id
    step_operator      = zenml_stack_component.step_operator.id
    image_builder      = zenml_stack_component.image_builder.id
  }

  labels = {
    "zenml:provider" = "azure"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

data "zenml_service_connector" "abc" {
  id = zenml_service_connector.abc.id
}

data "zenml_service_connector" "acr" {
  id = zenml_service_connector.acr.id
}

data "zenml_service_connector" "azure" {
  id = zenml_service_connector.azure.id
}

data "zenml_stack_component" "artifact_store" {
  id = zenml_stack_component.artifact_store.id
}

data "zenml_stack_component" "container_registry" {
  id = zenml_stack_component.container_registry.id
}

data "zenml_stack_component" "orchestrator" {
  id = zenml_stack_component.orchestrator.id
}

data "zenml_stack_component" "step_operator" {
  id = zenml_stack_component.step_operator.id
}

data "zenml_stack_component" "image_builder" {
  id = zenml_stack_component.image_builder.id
}

data "zenml_stack" "stack" {
  id = zenml_stack.stack.id
}
