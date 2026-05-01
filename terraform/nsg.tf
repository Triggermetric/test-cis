# =============================================================================
# nsg.tf — Network Security Group rules for the Cassandra cluster
#
# Rule priority map (100–4096, lower = evaluated first):
#   100  SSH from allowed_ssh_cidr
#   200  Cassandra native transport (9042)     — intra-VNet only
#   210  Cassandra inter-node gossip (7000)    — intra-VNet only
#   220  Cassandra JMX (7199)                  — intra-VNet only
#   260  ICMP (Ping)                           — intra-VNet only
#  4096  Deny all inbound (explicit, belt-and-suspenders)
#
# NOTE: Rules 300/310 open Grafana & Prometheus from the internet to node1's
# public IP. This is acceptable for a dev/lab setup; tighten allowed_ssh_cidr
# (or add a destination_address_prefix pointing only to node1's PIP) in prod.
# =============================================================================

resource "azurerm_network_security_group" "cassandra_primary" {
  name                = "${var.project_name}-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  # ---- SSH (port 22) -------------------------------------------------------
  # Source is configurable via var.allowed_ssh_cidr (default: any).
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "SSH access — restrict via allowed_ssh_cidr variable"
  }

  # ---- SSH (port 22) intra-VNet — for lateral administration -------------
  security_rule {
    name                       = "allow-ssh-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "SSH access — allow nodes to manage each other"
  }

  # ---- Cassandra native transport (9042) — clients & drivers ---------------
  security_rule {
    name                       = "allow-cassandra-native"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra CQL native transport — VNet only"
  }

  # ---- Cassandra gossip / inter-node (7000) --------------------------------
  security_rule {
    name                       = "allow-cassandra-gossip"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra gossip / inter-node — VNet only"
  }

  # ---- Cassandra JMX (7199) -----------------------------------------------
  security_rule {
    name                       = "allow-cassandra-jmx"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra JMX — VNet only"
  }


  # ---- ICMP (Ping) intra-VNet — all nodes ---------------------------------
  security_rule {
    name                       = "allow-icmp-vnet"
    priority                   = 260
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "ICMP (Ping) — intra-VNet access for diagnostics"
  }

  # ---- Backend API (8000) — from allowed SSH IPs --------------------------
  security_rule {
    name                       = "allow-backend-api"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "Backend API access (FastAPI on master) — from allowed IPs"
  }

  # ---- Frontend Dev Server (5173) — from allowed SSH IPs ------------------
  security_rule {
    name                       = "allow-frontend-dev"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5173"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "Frontend dev server (Vite) on master — from allowed IPs"
  }

  # ---- HTTP/HTTPS (80/443) — for future nginx frontend hosting -----------
  security_rule {
    name                       = "allow-http"
    priority                   = 320
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = ["*"]
    destination_address_prefix = "*"
    description                = "HTTP — for frontend nginx hosting (optional)"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 330
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = ["*"]
    destination_address_prefix = "*"
    description                = "HTTPS — for frontend nginx hosting (optional)"
  }

  # ---- Explicit deny-all inbound (belt-and-suspenders) --------------------
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Catch-all deny — anything not explicitly allowed above is dropped"
  }

  tags = {
    project = var.project_name
  }
}

resource "azurerm_network_security_group" "cassandra_secondary" {
  name                = "${var.project_name}-nsg-secondary"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.secondary_location

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "SSH access — restrict via allowed_ssh_cidr variable"
  }

  security_rule {
    name                       = "allow-ssh-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "SSH access — allow nodes to manage each other"
  }

  security_rule {
    name                       = "allow-cassandra-native"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra CQL native transport — VNet only"
  }

  security_rule {
    name                       = "allow-cassandra-gossip"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra gossip / inter-node — VNet only"
  }

  security_rule {
    name                       = "allow-cassandra-jmx"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "Cassandra JMX — VNet only"
  }

  security_rule {
    name                       = "allow-icmp-vnet"
    priority                   = 260
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = local.trusted_cluster_cidrs
    destination_address_prefix = "*"
    description                = "ICMP (Ping) — intra-VNet access for diagnostics"
  }

  # ---- Backend API (8000) — from allowed SSH IPs --------------------------
  security_rule {
    name                       = "allow-backend-api"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "Backend API access (FastAPI on master) — from allowed IPs"
  }

  # ---- Frontend Dev Server (5173) — from allowed SSH IPs ------------------
  security_rule {
    name                       = "allow-frontend-dev"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5173"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "Frontend dev server (Vite) on master — from allowed IPs"
  }

  # ---- HTTP/HTTPS (80/443) — for future nginx frontend hosting -----------
  security_rule {
    name                       = "allow-http"
    priority                   = 320
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = ["*"]
    destination_address_prefix = "*"
    description                = "HTTP — for frontend nginx hosting (optional)"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 330
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = ["*"]
    destination_address_prefix = "*"
    description                = "HTTPS — for frontend nginx hosting (optional)"
  }

  # ---- Explicit deny-all inbound (belt-and-suspenders) --------------------
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Catch-all deny — anything not explicitly allowed above is dropped"
  }

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# Associate the NSG with the Cassandra subnet
# All VMs in the subnet inherit these rules regardless of NIC-level NSGs.
# ---------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "cassandra" {
  subnet_id                 = azurerm_subnet.cassandra.id
  network_security_group_id = azurerm_network_security_group.cassandra_primary.id
}

resource "azurerm_subnet_network_security_group_association" "cassandra_secondary" {
  subnet_id                 = azurerm_subnet.cassandra_secondary.id
  network_security_group_id = azurerm_network_security_group.cassandra_secondary.id
}
