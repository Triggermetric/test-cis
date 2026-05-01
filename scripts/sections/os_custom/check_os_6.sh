#!/usr/bin/env bash
# Audit: Minimize swappiness to force Linux to use RAM instead of disk
audit_os_6() {
    local CHECK_ID="OS.6"
    local TITLE="Configure vm.swappiness"
    local SECTION="OS Custom Checks"
    local EXPECTED="0 or 1"
    local REMEDIATION="sysctl -w vm.swappiness=1"
    local SEVERITY="HIGH"

    local current_val=$(sysctl -n vm.swappiness 2>/dev/null || echo "Unknown")
    
    if [[ "$current_val" == "1" ]] || [[ "$current_val" == "0" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_os_6() { log_info "Setting vm.swappiness=1..."; sudo sysctl -w vm.swappiness=1; }
verify_os_6() { if ! audit_os_6 >/dev/null 2>&1; then harden_os_6; audit_os_6; else audit_os_6; fi; }
