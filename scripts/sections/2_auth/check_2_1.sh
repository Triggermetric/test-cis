#!/usr/bin/env bash
audit_2_1() {
    local CHECK_ID="2.1"
    local TITLE="Authentication enabled"
    local SECTION="2 Authentication and Authorization"
    local EXPECTED="PasswordAuthenticator"
    local REMEDIATION="Set authenticator: PasswordAuthenticator in cassandra.yaml"
    
    # Giả định file nằm ở /etc/cassandra/cassandra.yaml
    local val=$(grep "^authenticator:" /etc/cassandra/cassandra.yaml | awk '{print $2}' || echo "None")
    local status="FAIL"
    [[ "$val" == "PasswordAuthenticator" ]] && status="PASS"
    
    json_result "$CHECK_ID" "$TITLE" "$status" "CRITICAL" "$val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_2_1() {
    sed -i 's/^authenticator:.*/authenticator: PasswordAuthenticator/' /etc/cassandra/cassandra.yaml
    log_info "2.1 Hardened: Set authenticator to PasswordAuthenticator"
}
verify_2_1() { audit_2_1; }
