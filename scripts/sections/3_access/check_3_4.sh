#!/usr/bin/env bash
audit_3_4() {
    local CHECK_ID="3.4"
    local TITLE="Run using dedicated service account"
    local SECTION="3 Access Control"
    local EXPECTED="non-root user"
    local REMEDIATION="Run Cassandra with a dedicated non-privileged account."
    local SEVERITY="HIGH"

    local current_user
    current_user=$(ps -eo user,cmd | grep '[c]assandra' | grep java | awk '{print $1}' | head -n 1)

    if [[ -z "$current_user" ]]; then
        json_result "$CHECK_ID" "$TITLE" "ERROR" "$SEVERITY" "Not Running" "$EXPECTED" "Start Cassandra" "$SECTION"
    elif [[ "$current_user" == "root" ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "root" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_user" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_3_4() { log_warn "Manual action: Reconfigure service owner."; }
verify_3_4() { audit_3_4; }
