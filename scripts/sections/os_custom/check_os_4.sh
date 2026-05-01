#!/usr/bin/env bash
# Audit: Optimize TCP Keepalive for better network connection management
audit_os_4() {
    local CHECK_ID="OS.4"
    local TITLE="Optimize TCP Keepalive Time"
    local SECTION="OS Custom Checks"
    local EXPECTED="<= 300"
    local REMEDIATION="sysctl -w net.ipv4.tcp_keepalive_time=300"
    local SEVERITY="MEDIUM"

    local current_val=$(sysctl -n net.ipv4.tcp_keepalive_time 2>/dev/null || echo "Unknown")
    
    if [[ "$current_val" =~ ^[0-9]+$ ]] && [ "$current_val" -le 300 ]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_os_4() { log_info "Optimizing TCP Keepalive..."; sudo sysctl -w net.ipv4.tcp_keepalive_time=300; }
verify_os_4() { if ! audit_os_4 >/dev/null 2>&1; then harden_os_4; audit_os_4; else audit_os_4; fi; }
