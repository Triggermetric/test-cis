#!/usr/bin/env bash

# CIS 1.1: Ensure that a separate user and group are created for Cassandra
audit_1_1() {
    local CHECK_ID="1.1"
    local TITLE="Separate user and group for Cassandra"
    local SECTION="1 Installation and Updates"
    local EXPECTED="cassandra:cassandra"
    local SEVERITY="MEDIUM"

    if getent passwd cassandra > /dev/null && getent group cassandra > /dev/null; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "User 'cassandra' exists" "$EXPECTED" "" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "Missing cassandra user/group" "$EXPECTED" "Create cassandra user and group" "$SECTION"
    return 1
}

harden_1_1() {
    sudo groupadd cassandra 2>/dev/null || true
    # Create system user without login shell for better security
    sudo useradd -g cassandra -s /bin/false -m cassandra 2>/dev/null || true
}

verify_1_1() {
    if ! audit_1_1 > /dev/null 2>&1; then
        harden_1_1
        audit_1_1
    else
        audit_1_1
    fi
}
