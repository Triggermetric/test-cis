# =============================================================================
# keyvault.tf — Centralized secret management for the project
# =============================================================================

# ---------------------------------------------------------------------------
# Data Source to get current Azure client details (used for access policies)
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Random ID for unique naming (replaces timestamp to prevent destruction)
# ---------------------------------------------------------------------------
resource "random_id" "kv_suffix" {
  byte_length = 3
}

# ---------------------------------------------------------------------------
# Azure Key Vault — Storage for SSH keys, DB passwords, etc.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                        = "${var.project_name}-kv-${random_id.kv_suffix.hex}" # Append date for uniqueness
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  # Access policy: permit the current user/service-principal to manage secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "Create", "Delete", "List"
    ]

    secret_permissions = [
      "Get", "Set", "Delete", "List", "Purge", "Recover"
    ]
  }

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# SSH Public Key Secret — Store it for consistency (Member 1 requirement)
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "ssh_pub" {
  name         = "cassandra-ssh-pub"
  value        = file(var.ssh_public_key_path)
  key_vault_id = azurerm_key_vault.main.id
}

# ---------------------------------------------------------------------------
# Default Admin Password — Generated and stored securely
# ---------------------------------------------------------------------------
resource "random_password" "cassandra_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "cassandra_admin_pass" {
  name         = "cassandra-admin-password"
  value        = random_password.cassandra_admin.result
  key_vault_id = azurerm_key_vault.main.id
}
