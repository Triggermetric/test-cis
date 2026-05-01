# 🚀 Infrastructure Setup (Member 1)

This document summarizes the final state of the 4-node Cassandra cluster after handling Azure Student Subscription quota restrictions and Southeast Asia capacity issues.

### 📍 Cluster Overview

| Attribute            | Configuration                                     |
| :------------------- | :------------------------------------------------ |
| **Region**           | **Southeast Asia (Singapore)**                    |
| **VM Size (Master)** | `Standard_B2ats_v2` (1 vCPU / 1GB RAM) |
| **VM Size (DB)**     | `Standard_B2als_v2` (2 vCPU / 4GB RAM) |
| **Architecture**     | **x86_64 (AMD Standard)**              |
| **Operating System** | Ubuntu 22.04 LTS (Jammy)               |
| **Total Cores**      | 7 Cores (Master + 3xDB Nodes)          |

### 🛠️ Provisioned Resources

| Node       | Role          | Private IP  | Public IP      | SSH Command                                     |
| :--------- | :------------ | :---------- | :------------- | :---------------------------------------------- |
| **master** | Jump/Orch     | `10.0.1.10` | `4.194.10.192` | `ssh -i ~/.ssh/cis_key cassandra@4.194.10.192`  |
| **db1**    | Seed Node     | `10.0.1.11` | None (Private) | `ssh 10.0.1.11` (Jump from Master)              |
| **db2**    | Data Node     | `10.0.1.12` | None (Private) | `ssh 10.0.1.12` (Jump from Master)              |
| **db3**    | Data Node     | `10.0.1.13` | None (Private) | `ssh 10.0.1.13` (Jump from Master)              |

### 🔐 Access and Security

- **Jump Host Model**: For security, only the **Master** node has a public IP. All database nodes are hidden in a private subnet.
- **SSH Key Forwarding**: A private key has been pre-deployed to the Master node (`~/.ssh/id_rsa`) to allow seamless jumping to database nodes.
- **Whitelisted Access**: SSH is restricted to approved IP ranges defined in `terraform.tfvars`.

### ⚠️ Infrastructure Troubleshooting (Final Resolution)

- **Capacity Crisis**: 1-core VMs (`B1s`, `F1s`) were completely sold out in Southeast Asia.
- **Quota Lock**: The default 6-core limit blocked a 4-node cluster (4x2=8). The project was migrated to an **8-core subscription** to allow `Standard_B2als_v2` instances.
- **Architecture Shift**: Reverted from ARM64 to x86_64 for better compatibility with the available B-series AMD stock.

### 🏁 Team Hand-off & Connection Guide (Members 2 & 3)

#### 1. Connect to the Master Node
Use the provided `cis_key` to connect to the management entry point:
```bash
ssh -i "~/.ssh/cis_key" cassandra@4.194.10.192
```

#### 2. Accessing Database Nodes
Once inside the Master, you can access any database worker without further configuration:
```bash
# Example: Jump to the Seed node
ssh 10.0.1.11
```

#### 3. Security Audit Location
The security tools and benchmarking scripts are pre-installed on the Master node:
```bash
cd /opt/cis/
sudo ./cis-tool.sh audit all
```

---

_Updated for 4-Node x86_64 Production Baseline._
