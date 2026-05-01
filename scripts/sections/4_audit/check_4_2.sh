#!/usr/bin/env bash
audit_4_2() {
    local CHECK_ID="4.2"
    local TITLE="Auditing is enabled"
    local SECTION="4 Auditing and Logging"
    local EXPECTED="enabled: true"
    local REMEDIATION="Set enabled: true under audit_logging_options in cassandra.yaml."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(grep -A2 -i "^audit_logging_options:" /etc/cassandra/cassandra.yaml 2>/dev/null | grep "enabled:" | head -n 1 | awk '{print $2}' | tr -d '\r')
    [[ -z "$current_val" ]] && current_val="Not configured"

    # Mục này là MANUAL theo chuẩn CIS
    json_result "$CHECK_ID" "$TITLE" "MANUAL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_4_2() { log_warn "Manual action: Edit cassandra.yaml to enable audit_logging_options."; }
verify_4_2() { audit_4_2; }
