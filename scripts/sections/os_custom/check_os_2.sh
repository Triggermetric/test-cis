#!/usr/bin/env bash

# OS.2: Ensure strict permissions on cassandra.yaml
audit_os_2() {
    local CHECK_ID="OS.2"
    local TITLE="Strict permissions on cassandra.yaml"
    local SECTION="OS Custom"
    local EXPECTED="640 / cassandra:cassandra"
    local SEVERITY="MEDIUM"

    # Get current permissions and ownership
    local perms=$(stat -c "%a" /etc/cassandra/cassandra.yaml 2>/dev/null)
    local owner=$(stat -c "%U:%G" /etc/cassandra/cassandra.yaml 2>/dev/null)

    if [[ "$perms" == "640" ]] && [[ "$owner" == "cassandra:cassandra" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$perms ($owner)" "$EXPECTED" "" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$perms ($owner)" "$EXPECTED" "chmod 640 and chown cassandra" "$SECTION"
    return 1
}

harden_os_2() {
    # Remediation: Apply correct permissions and ownership
    sudo chown cassandra:cassandra /etc/cassandra/cassandra.yaml
    sudo chmod 640 /etc/cassandra/cassandra.yaml
}

verify_os_2() {
    if ! audit_os_2 > /dev/null 2>&1; then
        harden_os_2
        audit_os_2
    else
        audit_os_2
    fi
}
