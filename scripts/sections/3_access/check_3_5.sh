#!/usr/bin/env bash
audit_3_5() {
    local CHECK_ID="3.5"
    local TITLE="Listen on authorized interfaces"
    local SECTION="3 Access Control"
    local EXPECTED="Specific IP / Not 0.0.0.0"
    local REMEDIATION="Set listen_address to specific interface."
    local SEVERITY="HIGH"
    local current_val=$(grep "^listen_address:" /etc/cassandra/cassandra.yaml | awk '{print $2}')
    [[ -z "$current_val" ]] && current_val="Not configured"
    if [[ "$current_val" == "0.0.0.0" ]] || [[ "$current_val" == "localhost" ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
}
harden_3_5() {
    local host_ip=$(hostname -I | awk '{print $1}')
    [ -n "$host_ip" ] && sudo sed -i "s/^listen_address:.*/listen_address: $host_ip/" /etc/cassandra/cassandra.yaml
}
verify_3_5() { if ! audit_3_5 >/dev/null 2>&1; then harden_3_5; audit_3_5; else audit_3_5; fi; }
