# =============================================================================
# variables.tf — Input variables for cis-cassandra Azure infrastructure
# =============================================================================

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create all resources in"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "secondary_location" {
  description = "Secondary Azure region for overflow nodes"
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Absolute path to the SSH public key file (.pub) used for VM authentication. Password auth is disabled."
  type        = string
}

variable "allowed_ssh_ips" {
  description = <<-EOT
    List of CIDR blocks allowed to reach port 22 on the VMs.
    Include your teammates' public IPs here.
  EOT
  type    = list(string)
}

# ---------------------------------------------------------------------------
# Derived locals — centralise names so every resource uses the same pattern
# ---------------------------------------------------------------------------
locals {
  # 1 Master (Management) and 3 Database nodes split across two regions
  nodes = {
    master = { ip = "10.0.1.10", role = "master", is_seed = false, region = "primary" }
    db1    = { ip = "10.0.1.11", role = "db",     is_seed = true,  region = "primary" }
    db2    = { ip = "10.1.1.12", role = "db",     is_seed = false, region = "secondary" }
    db3    = { ip = "10.1.1.13", role = "db",     is_seed = false, region = "secondary" }
  }

  # CIDRs for dual-region networking
  primary_vnet_cidr    = "10.0.0.0/16"
  primary_subnet_cidr  = "10.0.1.0/24"
  secondary_vnet_cidr   = "10.1.0.0/16"
  secondary_subnet_cidr = "10.1.1.0/24"

  region_locations = {
    primary   = var.location
    secondary = var.secondary_location
  }

  # Both VNets are trusted cluster space
  trusted_cluster_cidrs = [local.primary_vnet_cidr, local.secondary_vnet_cidr]
  trusted_subnet_cidrs  = [local.primary_subnet_cidr, local.secondary_subnet_cidr]

  # DB1 is the primary seed for the cluster
  seed_node_key = "db1"
}
