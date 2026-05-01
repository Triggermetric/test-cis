#!/usr/bin/env bash
audit_2_2() {
    local CHECK_ID="2.1" # Theo PDF là 2.2
    local TITLE="Authorization enabled"
    local SECTION="2 Authentication and Authorization"
    local EXPECTED="CassandraAuthorizer"
    local REMEDIATION="Set authorizer: CassandraAuthorizer in cassandra.yaml"
    
    local val=$(grep "^authorizer:" /etc/cassandra/cassandra.yaml | awk '{print $2}' || echo "None")
    local status="FAIL"
    [[ "$val" == "CassandraAuthorizer" ]] && status="PASS"
    
    json_result "2.2" "$TITLE" "$status" "CRITICAL" "$val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_2_2() {
    sed -i 's/^authorizer:.*/authorizer: CassandraAuthorizer/' /etc/cassandra/cassandra.yaml
    log_info "2.2 Hardened: Set authorizer to CassandraAuthorizer"
}
verify_2_2() { audit_2_2; }
