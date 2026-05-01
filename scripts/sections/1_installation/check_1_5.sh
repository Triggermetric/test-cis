#!/usr/bin/env bash

audit_1_5() {
    local CHECK_ID="1.5"
    local TITLE="Run as non-root user"
    local SECTION="1 Installation and Updates"
    local EXPECTED="non-root"
    local REMEDIATION="Create a dedicated cassandra user and run the service with it."
    local SEVERITY="HIGH"

    local current_user
    current_user=$(ps -eo user,cmd | grep '[c]assandra' | grep java | awk '{print $1}' | head -n 1)

    if [[ -z "$current_user" ]]; then
        json_result "$CHECK_ID" "$TITLE" "ERROR" "$SEVERITY" "Not Running" "$EXPECTED" "Start Cassandra" "$SECTION"
    elif [[ "$current_user" == "root" ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_user" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_user" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}

harden_1_5() {
    log_info "Hardening 1.5: Creating cassandra user and changing ownership..."
    getent group cassandra > /dev/null || groupadd cassandra
    getent passwd cassandra > /dev/null || useradd -m -s /bin/bash -g cassandra cassandra
    
    log_info "Changing ownership of common Cassandra directories..."
    chown -R cassandra:cassandra /opt/cassandra /etc/cassandra /var/lib/cassandra /var/log/cassandra 2>/dev/null || true
    
    log_warn "Please update systemd service to use User=cassandra and restart."
}

verify_1_5() {
    audit_1_5
}
