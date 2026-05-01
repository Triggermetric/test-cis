# CHI TIẾT PHÂN CÔNG NHIỆM VỤ DỰ ÁN (TIẾN ĐỘ 4 TUẦN)
> **Môi trường triển khai:** Microsoft Azure (3 VM Ubuntu 22.04 trên Azure VNet)

---

## 1. Thành viên 1 – Infrastructure & DevOps (Nền tảng Azure)

**Vai trò:** Xây dựng toàn bộ hạ tầng Azure bằng Terraform, đảm bảo môi trường sẵn sàng cho nhóm trong tuần 1.

### Thiết lập cụm Cassandra trên Azure

- Tạo 3 Azure VM Ubuntu 22.04 (Standard_B2s: 2 vCPU, 4GB RAM) trong cùng một Azure VNet.
- Cấu hình IP tĩnh nội bộ: `10.0.1.11` (seed), `10.0.1.12`, `10.0.1.13`.
- Cài đặt OpenJDK 8, Python 3.10, Apache Cassandra 4.0.x trên mỗi VM.
- Cấu hình `cassandra.yaml`: Cluster Name, Seed Provider, Listen Address, RPC Address.

### Terraform IaC (azurerm provider)

- Toàn bộ hạ tầng được mô tả bằng Terraform: Resource Group, VNet, Subnet, NSG, VM, Public IP.
- Remote state lưu trên **Azure Blob Storage** (miễn phí với Azure for Students).
- Chạy `terraform apply` → có ngay 3 VM với Cassandra đã cài.

```
terraform/
├── main.tf          # Resource Group, VNet, Subnet
├── vms.tf           # 3 Azure Linux VM
├── nsg.tf           # Network Security Group rules
├── outputs.tf       # Public IPs, SSH commands
└── variables.tf     # vm_size, location, ssh_key_path
```

### Bảo mật hạ tầng Azure

- **Azure NSG** thay thế WireGuard VPN: chỉ cho phép port 22 (SSH) từ IP của nhóm, port 9042/7000/7199 chỉ trong VNet nội bộ.
- **Azure Key Vault** thay thế Infisical: lưu SSH private key, Cassandra credentials, Grafana password.
- **GitHub Actions OIDC** (Workload Identity Federation): CI/CD xác thực vào Azure không cần lưu secret vào GitHub.

### Observability

- Prometheus scrape JMX Exporter từ 3 nodes (port 9404).
- Grafana Dashboard: Heap memory, Read/Write latency, Disk usage, Node status.
- Chạy Prometheus + Grafana trên VM1 hoặc Azure Container Instance.

### Timeline

| Tuần | Mục tiêu | Deliverable |
|------|-----------|-------------|
| 1 | VM + Cassandra | 3 VM lên, cluster chạy, `nodetool status` xanh cả 3 node |
| 2 | Terraform + NSG | `terraform apply` tái tạo môi trường, NSG đúng rules |
| 3 | Key Vault + OIDC | Secret quản lý bằng Key Vault, CI/CD dùng OIDC auth |
| 4 | Monitoring + support | Grafana live metrics, hỗ trợ debug cho cả nhóm |

---

## 2. Thành viên 2 – CIS Scripting & Hardening (Logic bảo mật)

**Vai trò:** Xây dựng toàn bộ lớp automation script — 20 CIS checks + ~10 OS custom checks. Đây là nguồn dữ liệu cốt lõi cho Backend và Dashboard.

### Thư viện lõi (common.sh)

Phải hoàn thành tuần 1 trước khi làm bất kỳ check nào:

| Hàm | Chức năng |
|-----|-----------|
| `log_info/warn/fail` | Log màu (green/yellow/red) kèm timestamp |
| `json_result` | Xuất JSON chuẩn cho mỗi check |
| `check_root` | Kiểm tra quyền root |
| `run_remote <ip> <cmd>` | SSH vào node khác và chạy lệnh |
| `cassandra_yaml_get` | Đọc giá trị từ cassandra.yaml |
| `cqlsh_query` | Chạy CQL query, handle lỗi connection |

### 20 CIS Checks (mỗi check gồm 3 hàm: audit, harden, verify)

| ID | Tên check | Loại | Tuần |
|----|-----------|------|------|
| 1.1 | Separate user/group for Cassandra | Manual | 1 |
| 1.2 | Latest Java version | Automated | 1 |
| 1.3 | Latest Python version | Automated | 1 |
| 1.4 | Latest Cassandra version | Automated | 1 |
| 1.5 | Run as non-root user | Automated | 1 |
| 1.6 | Clock synchronized (NTP) | Manual | 1 |
| 2.1 | Authentication enabled (PasswordAuthenticator) | Automated | 2 |
| 2.2 | Authorization enabled (CassandraAuthorizer) | Automated | 2 |
| 3.1 | cassandra/superuser roles are separate | Automated | 2 |
| 3.2 | Default password changed | Automated | 2 |
| 3.3 | No unnecessary roles/excessive privileges | Manual | 2 |
| 3.4 | Non-privileged service account | Automated | 2 |
| 3.5 | Listen only on authorized interfaces | Manual | 2 |
| 3.6 | Data Center Authorization activated | Manual | 3 |
| 3.7 | Review User-Defined Roles | Manual | 3 |
| 3.8 | Review Superuser/Admin Roles | Manual | 3 |
| 4.1 | Logging is enabled | Automated | 3 |
| 4.2 | Auditing is enabled | Manual | 3 |
| 5.1 | Inter-node encryption (TLS) | Automated | 3 |
| 5.2 | Client encryption (TLS) | Automated | 3 |

Ngoài ra bổ sung ~10 OS-level custom checks: file permissions, sysctl hardening, SSH config security.

### JSON Schema (thống nhất với Member 3 — tuần 1)

```json
{
  "check_id": "2.1",
  "title": "Authentication enabled",
  "status": "FAIL",
  "severity": "CRITICAL",
  "current_value": "AllowAllAuthenticator",
  "expected_value": "PasswordAuthenticator",
  "remediation": "Set authenticator: PasswordAuthenticator",
  "section": "Authentication and Authorization",
  "node": "10.0.1.11",
  "timestamp": "2026-04-01T10:00:00Z"
}
```

**Lưu ý quan trọng:** `exit code 0` = tất cả PASS, `exit code 1` = có FAIL. CI/CD dùng exit code này để block merge.

### cis-tool.sh modes

| Lệnh | Chức năng |
|------|-----------|
| `--audit [--section N]` | Chạy audit, xuất JSON |
| `--harden [--section N]` | Áp dụng hardening |
| `--verify` | Verify sau harden |
| `--all-nodes` | Chạy song song trên cả 3 VM |
| `--output report.json` | Tổng hợp kết quả |

---

## 3. Thành viên 3 – Backend API & System Integration

**Vai trò:** FastAPI backend điều phối script bash qua SSH, cung cấp dữ liệu cho Dashboard.

### Stack

- **FastAPI** + **asyncssh** + **Pydantic v2** + **pytest**
- SSH key auth vào 3 Azure VM (key lưu trong Azure Key Vault, inject qua env)

### API Endpoints

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/cluster/status` | Status 3 nodes (reachable, Cassandra running, latency) |
| GET | `/api/audit/cluster` | Audit toàn cluster, trả JSON |
| GET | `/api/audit/node/{ip}` | Audit 1 node |
| GET | `/api/audit/stream/{ip}` | **SSE stream** — live output khi audit chạy |
| POST | `/api/harden/node/{ip}` | Trigger harden script |
| GET | `/health` | Health check endpoint |

### SSE Streaming (Server-Sent Events)

SSE là lựa chọn tốt hơn WebSocket cho trường hợp này (server → client one-way stream). Backend stream từng dòng output từ cis-tool.sh về frontend real-time qua SSE.

### Pydantic Models (khớp với JSON schema của Member 2)

```python
class CheckResult(BaseModel):
    check_id: str
    title: str
    status: Literal['PASS', 'FAIL', 'MANUAL', 'ERROR']
    severity: Literal['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
    current_value: str
    expected_value: str
    remediation: str
    section: str
    node: str
    timestamp: datetime
```

### Timeline

| Tuần | Mục tiêu | Deliverable |
|------|-----------|-------------|
| 1 | Scaffold + schema | FastAPI project, Pydantic models, thống nhất JSON schema với Member 2 |
| 2 | Core API | `/cluster/status`, `/audit/*`, `/harden/*` hoàn chỉnh |
| 3 | SSE stream | `/audit/stream/{ip}` stream live, pytest 36 tests pass |
| 4 | Integration | Test đầu cuối với Member 2 và 4, fix edge cases |

---

## 4. Thành viên 4 – Frontend Dashboard & CI/CD Pipeline

**Vai trò:** Dashboard 4 trang + CI/CD security gate chặn merge khi có lỗi CRITICAL.

### Frontend: 4 trang (React 18 + Vite + Tailwind)

| Trang | Nội dung | Tính năng |
|-------|----------|-----------|
| **Dashboard** | Score gauge 3 nodes, cluster health overview | Auto-refresh 30s, nút Run Audit All |
| **Compliance** | Bảng 20+ checks, filter theo status/section | Click xem evidence + Auto-Remediate |
| **Audit Live** | Terminal stream real-time khi audit chạy | Node selector, Start/Stop, auto-scroll |
| **Monitoring** | Grafana iframe + quick links | Link đến Prometheus, API docs |

**Audit Live page** là điểm ấn tượng nhất trong demo: thấy từng dòng output SSH chạy trong trình duyệt real-time.

### CI/CD Pipeline: 5 jobs

```
lint-bash ──────────────────────────────────────────┐
test-backend ───────────────────────────────────────┤──► security-gate (CRITICAL block)
test-frontend (tsc + vitest + build) ───────────────┤
trivy-scan (CVE + filesystem) ──────────────────────┘
```

### Security Gate (điểm DevSecOps thực sự)

```bash
# Block merge nếu có CIS check CRITICAL bị FAIL
CRITICAL=$(jq '[.checks[] | select(.status=="FAIL" and .severity=="CRITICAL")] | length' audit-fixture.json)
if [ "$CRITICAL" -gt 0 ]; then
  echo "❌ BLOCKED: $CRITICAL critical CIS violations"
  exit 1
fi
```

**Demo kịch bản:** Commit cấu hình Cassandra thiếu authentication → pipeline đỏ → merge bị block → fix → pipeline xanh. Đây là DevSecOps security gate thực sự.

### Trivy (CVE Scanning)

- Quét toàn bộ filesystem repo tìm vulnerability CRITICAL/HIGH
- Quét Python dependencies (`requirements.txt`) tìm CVE đã biết
- Kết quả upload lên GitHub Security tab (SARIF format)

### ESLint Security Plugin

- Phát hiện XSS, injection risk trong React code
- Chạy trong `test-frontend` job

### Branch Protection Rules (setup trên GitHub)

- Require `security-gate` job pass trước khi merge
- Dismiss stale approvals sau khi push mới
- Require linear history (squash merge)

### Timeline

| Tuần | Mục tiêu | Deliverable |
|------|-----------|-------------|
| 1 | Scaffold | Vite+React+Tailwind, TypeScript types, CI skeleton |
| 2 | Dashboard + Compliance | 2 trang chính kết nối API thật |
| 3 | Audit Live + CI gate | Terminal stream page, security gate block CRITICAL, Trivy |
| 4 | Polish + demo | Score animation, demo script chuẩn, responsive |
