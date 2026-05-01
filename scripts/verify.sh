#!/usr/bin/env bash
# ==============================================================================
#  CIS Cassandra 4.0 Benchmark - Consolidated Verification Script
#  Consolidates Automated & Manual checks into a single PDF-style report.
# ==============================================================================

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Configuration
RG="${AZURE_RESOURCE_GROUP:-rg-cis-cassandra}"
PROJECT_NAME="${PROJECT_NAME:-cis-cassandra}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper to run commands via Azure (bypassing SSH blocks)
run_cmd() {
  local vm_name="$1"
  local cmd="$2"
  
  az vm run-command invoke -g "$RG" -n "$vm_name" \
      --command-id RunShellScript --scripts "$cmd" \
      --query "value[0].message" -o tsv 2>/dev/null
}

format_status() {
  case "$1" in
    PASS) echo -e "${GREEN}[PASS]${NC}" ;;
    FAIL) echo -e "${RED}[FAIL]${NC}" ;;
    NEEDS_REVIEW|WARN) echo -e "${YELLOW}[WARN]${NC}" ;;
    *) echo -e "[${1}]" ;;
  esac
}

print_header() {
    echo -e "\n${CYAN}===========================================================================${NC}"
    echo -e "${CYAN}  CIS CASSANDRA 4.0 BENCHMARK VERIFICATION REPORT${NC}"
    echo -e "${CYAN}  Generated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}===========================================================================${NC}"
}

print_node_header() {
    echo -e "\n${CYAN}>>> NODE: $1 ($2)${NC}"
    echo -e "---------------------------------------------------------------------------"
    printf "%-8s %-60s %-8s\n" "ID" "RECOMMENDATION TITLE" "STATUS"
    echo -e "---------------------------------------------------------------------------"
}

print_header

LABELS=("node1" "node2" "node3")
VM_NAMES=("${PROJECT_NAME}-node1" "${PROJECT_NAME}-node2" "${PROJECT_NAME}-node3")
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo -e "${YELLOW}[INFO] Requesting audit data from all nodes in parallel via Azure...${NC}"
echo -e "${YELLOW}[INFO] This usually takes 45-60 seconds. Please wait.${NC}"

# Launch all in parallel
for i in "${!LABELS[@]}"; do
    label="${LABELS[$i]}"
    vm_name="${VM_NAMES[$i]}"
    (
        output=$(run_cmd "$vm_name" "sudo bash /opt/cis/cis-tool.sh audit all")
        if [ -n "$output" ]; then
            echo "$output" > "$TMP_DIR/$label.json"
        else
            echo "ERROR: Failed to retrieve data from $vm_name" > "$TMP_DIR/$label.err"
        fi
    ) &
done

# Wait for all background tasks
wait

# Process and print results
for i in "${!LABELS[@]}"; do
    label="${LABELS[$i]}"
    vm_name="${VM_NAMES[$i]}"
    
    print_node_header "$label" "$vm_name"

    if [ -f "$TMP_DIR/$label.json" ]; then
        output=$(cat "$TMP_DIR/$label.json")
        if echo "$output" | grep -q '{"id":'; then
            if command -v jq >/dev/null 2>&1; then
                echo "$output" | jq -r '.checks[] | "\(.id)\t\(.title)\t\(.status)"' | while IFS=$'\t' read -r id title status; do
                    printf "%-8s %-60s %b\n" "$id" "${title:0:58}" "$(format_status "$status")"
                done
            else
                echo "$output" | grep -o '{"id":"[^"]*","title":"[^"]*","status":"[^"]*"' | sed 's/[{}]//g; s/"//g' | while IFS=',' read -r i t s; do
                    id=$(echo "$i" | cut -d: -f2)
                    title=$(echo "$t" | cut -d: -f2)
                    status=$(echo "$s" | cut -d: -f2)
                    printf "%-8s %-60s %b\n" "$id" "${title:0:58}" "$(format_status "$status")"
                done
            fi
        else
             echo -e "${RED}[ERROR] Output from $label was not valid compliance data.${NC}"
             echo -e "Full output log: $output"
        fi
    else
        err_msg=$(cat "$TMP_DIR/$label.err" 2>/dev/null || echo "Unknown error")
        echo -e "${RED}[ERROR] $err_msg${NC}"
        echo -e "${YELLOW}[TIP] Ensure the CIS toolkit is deployed with: ./cis-tool.sh cluster deploy${NC}"
    fi
done

echo -e "\n${CYAN}===========================================================================${NC}"
echo -e "  Verification Complete.${NC}"
echo -e "${CYAN}===========================================================================${NC}"
