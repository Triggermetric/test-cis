#!/usr/bin/env bash
audit_5_2() {
    local CHECK_ID="5.2"
    local TITLE="Client Encryption (TLS)"
    local SECTION="5 Encryption"
    local EXPECTED="enabled: true, optional: false"
    local REMEDIATION="Set enabled to true and optional to false in cassandra.yaml."
    local SEVERITY="HIGH"
    local enabled_val=$(sed -n '/client_encryption_options:/,/^[^ ]/p' /etc/cassandra/cassandra.yaml | grep "enabled:" | head -n 1 | awk '{print $2}')
    if [[ "$enabled_val" == "true" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "enabled: $enabled_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "enabled: $enabled_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    fi
}
harden_5_2() {
    sudo sed -i '/client_encryption_options:/,/optional:/ s/enabled: false/enabled: true/' /etc/cassandra/cassandra.yaml
}
verify_5_2() { if ! audit_5_2 >/dev/null 2>&1; then harden_5_2; audit_5_2; else audit_5_2; fi; }
