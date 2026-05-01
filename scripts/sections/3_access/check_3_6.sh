#!/usr/bin/env bash

# CIS 3.6: Ensure that Data Center Authorizations are activated
audit_3_6() {
    local CHECK_ID="3.6"
    local TITLE="Data Center Authorizations activated"
    local SECTION="3 Access Control"
    local EXPECTED="CassandraNetworkAuthorizer"
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(grep "^network_authorizer:" /etc/cassandra/cassandra.yaml | awk '{print $2}')
    
    if [[ "$current_val" == "CassandraNetworkAuthorizer" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "${current_val:-AllowAllNetworkAuthorizer}" "$EXPECTED" "Set network_authorizer to CassandraNetworkAuthorizer" "$SECTION"
    return 1
}

harden_3_6() {
    # Replace AllowAllNetworkAuthorizer with CassandraNetworkAuthorizer
    sudo sed -i 's/^network_authorizer:.*/network_authorizer: CassandraNetworkAuthorizer/' /etc/cassandra/cassandra.yaml
}

verify_3_6() {
    if ! audit_3_6 > /dev/null 2>&1; then
        harden_3_6
        audit_3_6
    else
        audit_3_6
    fi
}
