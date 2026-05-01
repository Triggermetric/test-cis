#!/usr/bin/env bash
# Audit: Increase max map count to prevent out-of-memory errors
audit_os_7() {
    local CHECK_ID="OS.7"
    local TITLE="Configure vm.max_map_count"
    local SECTION="OS Custom Checks"
    local EXPECTED=">= 1048575"
    local REMEDIATION="sysctl -w vm.max_map_count=1048575"
    local SEVERITY="MEDIUM"

    local current_val=$(sysctl -n vm.max_map_count 2>/dev/null || echo "Unknown")
    
    if [[ "$current_val" =~ ^[0-9]+$ ]] && [ "$current_val" -ge 1048575 ]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_os_7() { log_info "Setting vm.max_map_count=1048575..."; sudo sysctl -w vm.max_map_count=1048575; }
verify_os_7() { if ! audit_os_7 >/dev/null 2>&1; then harden_os_7; audit_os_7; else audit_os_7; fi; }
