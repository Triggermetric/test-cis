# =============================================================================
# outputs.tf — Useful values printed after `terraform apply`
# =============================================================================

# ---------------------------------------------------------------------------
# Public IPs — needed to SSH into each node from outside the VNet
# ---------------------------------------------------------------------------
output "public_ips" {
  description = "Public IP addresses (Master only)"
  value = {
    for k, pip in azurerm_public_ip.node : k => pip.ip_address
  }
}

# ---------------------------------------------------------------------------
# Private IPs — static, used by Cassandra seed config and intra-cluster comms
# ---------------------------------------------------------------------------
output "private_ips" {
  description = "Static private IP addresses for each Cassandra node"
  value = {
    for k, node in local.nodes : k => node.ip
  }
}

# ---------------------------------------------------------------------------
# SSH commands — copy-paste ready after apply
# ---------------------------------------------------------------------------
output "ssh_commands" {
  description = "SSH commands (Direct for Master, Internal for DB nodes)"
  value = {
    for k, v in local.nodes :
    k => lookup(azurerm_public_ip.node, k, null) != null ? 
         "ssh cassandra@${azurerm_public_ip.node[k].ip_address} (EXTERNAL)" : 
         "ssh cassandra@${v.ip} (INTERNAL via Master)"
  }
}

# ---------------------------------------------------------------------------
# Cassandra seed address — needed by Ansible/scripts to configure cassandra.yaml
# ---------------------------------------------------------------------------
output "seed_node_private_ip" {
  description = "Private IP of the seed node (db1) — set as seeds in cassandra.yaml"
  value       = local.nodes[local.seed_node_key].ip
}


# ---------------------------------------------------------------------------
# Resource Group name — handy for follow-up `az` CLI commands
# ---------------------------------------------------------------------------
output "resource_group_name" {
  description = "Azure Resource Group containing all cis-cassandra resources"
  value       = azurerm_resource_group.main.name
}
