# =============================================================================
# vms.tf — Public IPs, NICs, and Linux VMs for the 3-node Cassandra cluster
# =============================================================================

# ---------------------------------------------------------------------------
# cloud-init script (base64-encoded) — runs once at first boot
# Installs: OpenJDK 11, Python 3.10, Apache Cassandra 4.0
# Cassandra is installed via the official Apache apt repo so version is fixed.
# ---------------------------------------------------------------------------
locals {
  # Common packages for all nodes
  base_packages = ["apt-transport-https", "gnupg", "curl", "python3.10", "python3-pip", "openjdk-11-jdk"]

  # ---- Master Node Init (Management Tools Only) ----
  raw_master_init = <<-CLOUDINIT
    #cloud-config
    package_update: true
    packages: ${jsonencode(local.base_packages)}
    runcmd:
      - echo "Master node ready for DevSecOps tasks" > /etc/motd
    final_message: "cis-master ready"
  CLOUDINIT

  # ---- DB Node Init (Cassandra 4.0) ----
  raw_db_init = <<-CLOUDINIT
    #cloud-config
    package_update: true
    packages: ${jsonencode(local.base_packages)}
    runcmd:
      - [ bash, -c, 'curl -s https://downloads.apache.org/cassandra/KEYS | gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg' ]
      - [ bash, -c, 'echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 40x main" > /etc/apt/sources.list.d/cassandra.list' ]
      - [ apt-get, update, -qq ]
      - [ apt-get, install, -y, cassandra ]
      - [ update-alternatives, --set, java, /usr/lib/jvm/java-11-openjdk-amd64/bin/java ]
      - [ bash, -c, 'sed -i "s/seeds: .*/seeds: \"10.0.1.11\"/" /etc/cassandra/cassandra.yaml' ]
      - [ bash, -c, "sed -i \"s/listen_address: localhost/listen_address: $(hostname -i)/\" /etc/cassandra/cassandra.yaml" ]
      - [ bash, -c, "sed -i \"s/rpc_address: localhost/rpc_address: 0.0.0.0/\" /etc/cassandra/cassandra.yaml" ]
      - [ bash, -c, "sed -i \"s/# broadcast_rpc_address: 1.2.3.4/broadcast_rpc_address: $(hostname -i)/\" /etc/cassandra/cassandra.yaml" ]
      - [ bash, -c, 'sed -i "s/endpoint_snitch: .*/endpoint_snitch: GossipingPropertyFileSnitch/" /etc/cassandra/cassandra.yaml' ]
      - [ systemctl, enable, cassandra ]
      - [ systemctl, start, cassandra ]
    final_message: "cis-db-node ready"
  CLOUDINIT

  cloud_init_master = base64encode(replace(local.raw_master_init, "\r\n", "\n"))
  cloud_init_db     = base64encode(replace(local.raw_db_init, "\r\n", "\n"))
}

# Public IPs — ONLY for the Master node due to subscription limits
resource "azurerm_public_ip" "node" {
  for_each = { for k, v in local.nodes : k => v if v.role == "master" }

  name                = "${var.project_name}-${each.key}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.region_locations[each.value.region]
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    project = var.project_name
    node    = each.key
  }
}

# ---------------------------------------------------------------------------
# Network Interfaces — static private IP so Cassandra seed address is stable
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "node" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.region_locations[each.value.region]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.region == "primary" ? azurerm_subnet.cassandra.id : azurerm_subnet.cassandra_secondary.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    # Only associate Public IP if it exists for this node
    public_ip_address_id          = lookup(azurerm_public_ip.node, each.key, null) != null ? azurerm_public_ip.node[each.key].id : null
  }

  tags = {
    project = var.project_name
    node    = each.key
  }
}

# ---------------------------------------------------------------------------
# Associate each NIC with the Cassandra NSG defined in nsg.tf
# ---------------------------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "node" {
  for_each = local.nodes

  network_interface_id      = azurerm_network_interface.node[each.key].id
  network_security_group_id = each.value.region == "primary" ? azurerm_network_security_group.cassandra_primary.id : azurerm_network_security_group.cassandra_secondary.id
}

# ---------------------------------------------------------------------------
# Linux Virtual Machines — Ubuntu 22.04 LTS
# Password auth is explicitly disabled; SSH key is the only access method.
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "node" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.region_locations[each.value.region]
  size                = (each.key == "master") ? "Standard_B2ats_v2" : var.vm_size

  # Admin account — password auth disabled, key-only
  admin_username                  = "cassandra"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "cassandra"
    public_key = file(var.ssh_public_key_path)
  }

  # Attach the NIC with the static private IP
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  # OS disk — standard SSD is sufficient for a dev cluster
  os_disk {
    name                 = "${var.project_name}-${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  # Ubuntu 22.04 LTS from Canonical
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # cloud-init selection based on role
  custom_data = each.value.role == "master" ? local.cloud_init_master : local.cloud_init_db

  tags = {
    project = var.project_name
    node    = each.key
    role    = each.value.role
    type    = each.value.is_seed ? "seed" : "standard"
  }
}
