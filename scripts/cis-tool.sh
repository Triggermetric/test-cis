#!/usr/bin/env bash
# cis-tool.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib/common.sh" ] && source "$SCRIPT_DIR/lib/common.sh"

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

# --- Dashboard UI ---
print_dashboard() {
    local json_file=$1
    local node_name=$2
    echo -e "\n\e[36m>>> NODE: $node_name\e[0m"
    echo "------------------------------------------------------------------------------------------"
    printf "%-7s %-65s %-10s\n" "ID" "RECOMMENDATION TITLE" "STATUS"
    echo "------------------------------------------------------------------------------------------"
    if [ ! -f "$json_file" ] || [ ! -s "$json_file" ]; then
        echo -e "\e[31mERROR: Report empty or not found for $node_name\e[0m"
        return
    fi
    sed 's/},{/}\n{/g' "$json_file" | while read -r line; do
        local id=$(echo "$line" | sed -n 's/.*"check_id":"\([^"]*\)".*/\1/p')
        local title=$(echo "$line" | sed -n 's/.*"title":"\([^"]*\)".*/\1/p')
        local status=$(echo "$line" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
        [ -z "$id" ] && continue
        local color=$NC
        case "$status" in
            PASS) color=$GREEN ;;
            FAIL|ERROR) color=$RED ;;
            *) color=$YELLOW ;;
        esac
        # Removed brackets and icons for a clean English output
        printf "%-7s %-65.63s ${color}%-6s${NC}\n" "$id" "$title" "$status"
    done
}

# --- Core Task ---
run_task() {
    local mode=$1
    local target=$2
    local TMPFILE=$(mktemp)
    local DIRS_TO_SCAN=()
    
    if [[ "$target" == "all" ]]; then
        for d in "$SCRIPT_DIR/sections"/*/; do [[ -d "$d" ]] && DIRS_TO_SCAN+=("$d"); done
    else
        local found=$(find "$SCRIPT_DIR/sections" -maxdepth 1 -type d -name "${target}_*" | head -n 1)
        [[ -n "$found" ]] && DIRS_TO_SCAN+=("$found/")
    fi

    for SEARCH_DIR in "${DIRS_TO_SCAN[@]}"; do
        for script in $(find "$SEARCH_DIR" -name "check_*.sh" | sort); do
            source "$script"
            local suffix=$(basename "$script" .sh | sed 's/check_//')
            if [[ "$mode" == "verify" ]]; then
                verify_${suffix} >> "$TMPFILE"
            elif [[ "$mode" == "harden" ]]; then
                harden_${suffix}
            else
                audit_${suffix} >> "$TMPFILE"
            fi
        done
    done

    if [[ "$mode" == "verify" || "$mode" == "audit" ]]; then
        local REPORT_PATH="$SCRIPT_DIR/reports/report.json"
        mkdir -p "$SCRIPT_DIR/reports"
        build_report "$(hostname -I | awk '{print $1}')" "$TMPFILE" > "$REPORT_PATH"
        chmod 666 "$REPORT_PATH"
    fi
    rm -f "$TMPFILE"
}

# --- Main Dispatcher ---
case "${1:-}" in
    audit)  run_task "audit" "${2:-all}" ;;
    harden) run_task "harden" "${2:-all}" ;;
    verify) 
        run_task "verify" "all" 
        echo -e "${YELLOW}WARNING: Some security changes (TLS, Auth, Logging) require a service restart.${NC}"
        echo -e "${YELLOW}ACTION: Please perform a ROLLING RESTART to avoid downtime.${NC}"
        print_dashboard "$SCRIPT_DIR/reports/report.json" "$(hostname)"
        ;;
    cluster)
        action=${2:-verify}
        workers=("10.0.1.11" "10.0.1.12" "10.0.1.13")
        
        echo -e "${CYAN}=========================================================${NC}"
        echo -e "${CYAN}STARTING CLUSTER-WIDE AUTO-HARDEN (${action^^})${NC}"
        echo -e "${CYAN}=========================================================${NC}"

        echo -e "\n\e[33m[+] Executing on MASTER NODE...\e[0m"
        sudo "$0" "$action"

        for ip in "${workers[@]}"; do
            echo -e "\n\e[33m[+] Syncing and executing on NODE: $ip...\e[0m"
            rsync -az -e ssh "$SCRIPT_DIR/" cassandra@$ip:~/cis-cassandra/scripts/
            ssh -t cassandra@$ip "sudo ~/cis-cassandra/scripts/cis-tool.sh $action"
        done
        
        echo -e "\n\e[32mSUCCESS: Cluster hardening completed successfully.\e[0m"
        ;;
    *)      
        echo "Usage: $0 {audit|harden|verify|cluster}"
        exit 1 
        ;;
esac
