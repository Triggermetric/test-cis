# =============================================================================
# main.tf — Provider, backend, Resource Group, VNet, Subnet
# =============================================================================

# ---------------------------------------------------------------------------
# Remote State — Azure Blob Storage backend
# Uncomment the terraform{} block below and fill in your values BEFORE running
# `terraform init` for the first time.
# Pre-requisites:
#   az group create -n tfstate-rg -l "Southeast Asia"
#   az storage account create -n <SA_NAME> -g tfstate-rg --sku Standard_LRS
#   az storage container create -n tfstate --account-name <SA_NAME>
# ---------------------------------------------------------------------------

/*
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "sttfstate1465"
    container_name       = "tfstate"
    key                  = "cis-cassandra/terraform.tfstate"
  }
}
*/

# ---------------------------------------------------------------------------
# Provider — pin to azurerm ~> 3.0 to avoid breaking changes from v4
# ---------------------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ---------------------------------------------------------------------------
# Resource Group — logical container for every resource in this project
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = var.project_name
    environment = "dev"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Virtual Network — /16 gives plenty of room for future subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = [local.primary_vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# Subnet — /24 hosts all 3 Cassandra nodes (10.0.1.11–13)
# NSG is associated in nsg.tf via azurerm_subnet_network_security_group_association
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "cassandra" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.primary_subnet_cidr]
}

# ---------------------------------------------------------------------------
# Secondary Virtual Network + Subnet — hosts overflow Cassandra nodes
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "secondary" {
  name                = "${var.project_name}-vnet-secondary"
  address_space       = [local.secondary_vnet_cidr]
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = var.project_name
  }
}

resource "azurerm_subnet" "cassandra_secondary" {
  name                 = "${var.project_name}-subnet-secondary"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = [local.secondary_subnet_cidr]
}

# ---------------------------------------------------------------------------
# VNet peering — enables private traffic across the two regions
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                      = "${var.project_name}-peer-primary-to-secondary"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = azurerm_virtual_network.secondary.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  name                      = "${var.project_name}-peer-secondary-to-primary"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.secondary.name
  remote_virtual_network_id = azurerm_virtual_network.main.id
  allow_virtual_network_access = true
}
