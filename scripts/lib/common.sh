#!/usr/bin/env bash
CASSANDRA_YAML="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
LOGBACK_XML="${LOGBACK_XML:-/etc/cassandra/logback.xml}"
CASSANDRA_ENV="${CASSANDRA_ENV:-/etc/cassandra/cassandra-env.sh}"
NODE_IPS=("4.193.213.85" "4.193.208.18" "4.193.98.211")
SSH_KEY="${CIS_SSH_KEY:-$HOME/.ssh/cis_key}"
SSH_USER="${CIS_SSH_USER:-cassandra}"

NC='\033[0m'
if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; else GREEN=''; RED=''; YELLOW=''; CYAN=''; BLUE=''; NC=''; fi

# Các hàm ghi log chuẩn
log_info() { [ -t 1 ] && echo -e "${BLUE}[INFO]${NC} $(date +'%Y-%m-%dT%H:%M:%SZ') - $*" || echo "[INFO] $*"; }
log_ok()   { [ -t 1 ] && echo -e "${GREEN}[OK]${NC} $(date +'%Y-%m-%dT%H:%M:%SZ') - $*"   || echo "[OK] $*"; }
log_warn() { [ -t 1 ] && echo -e "${YELLOW}[WARN]${NC} $(date +'%Y-%m-%dT%H:%M:%SZ') - $*" || echo "[WARN] $*"; }
log_err()  { [ -t 1 ] && echo -e "${RED}[ERR]${NC} $(date +'%Y-%m-%dT%H:%M:%SZ') - $*"  || echo "[ERR] $*"; }

# Hàm kiểm tra quyền Root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_err "Please run using root (sudo)."
        exit 1
    fi
}

# Hàm xuất JSON cho Backend (Member 3)
json_result() {
  local id="$1" title="$2" status="$3" severity="$4" current="$5" expected="$6" remediation="$7" section="$8"
  local node_ip=$(hostname -I | awk '{print $1}')
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  current=$(printf '%s' "$current" | head -3 | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g')
  printf '{"check_id":"%s","title":"%s","status":"%s","severity":"%s","current_value":"%s","expected_value":"%s","remediation":"%s","section":"%s","node":"%s","timestamp":"%s"}\n' "$id" "$title" "$status" "$severity" "$current" "$expected" "$remediation" "$section" "$node_ip" "$timestamp"
}

# Các hàm thao tác với Cassandra
cassandra_yaml_get() { grep "^$1:" "$CASSANDRA_YAML" | awk '{print $2}' | tr -d '\r'; }
cassandra_yaml_set() { sed -i "s/^$1:.*/$1: $2/" "$CASSANDRA_YAML"; }
# 3. CQL Query Execution Tool
# 3. CQL Query Execution Tool
cqlsh_query() {
    local query="$1"
    local creds_file="/etc/cassandra/.db_creds"
    
    if [[ -f "$creds_file" ]]; then
        source "$creds_file"
        sudo CQLSH_PYTHON=/usr/bin/python3.11 /opt/cassandra/bin/cqlsh --ssl -u "$CASSANDRA_USER" -p "$CASSANDRA_PASS" -e "${query}" | grep -v '^-' | grep -v '^$'
    else
        sudo CQLSH_PYTHON=/usr/bin/python3.11 /opt/cassandra/bin/cqlsh --ssl -e "${query}" | grep -v '^-' | grep -v '^$'
    fi
}

# Hàm gom Report cuối cùng
build_report() {
  local node="$1" checks_file="$2"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local total=$(grep -c '"check_id":' "$checks_file" 2>/dev/null || echo 0)
  local passed=$(grep -c '"status":"PASS"' "$checks_file" 2>/dev/null || echo 0)
  local failed=$(grep -c '"status":"FAIL"' "$checks_file" 2>/dev/null || echo 0)
  local manual=$(grep -c '"status":"MANUAL"' "$checks_file" 2>/dev/null || echo 0)
  
  printf '{\n  "node": "%s",\n  "timestamp": "%s",\n  "score": {\n    "total": %s,\n    "passed": %s,\n    "failed": %s,\n    "manual": %s\n  },\n  "checks": [\n' "$node" "$timestamp" "$total" "$passed" "$failed" "$manual"
  
  local first=true
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if $first; then printf '    %s' "$line"; first=false; else printf ',\n    %s' "$line"; fi
  done < "$checks_file"
  printf '\n  ]\n}\n'
}
