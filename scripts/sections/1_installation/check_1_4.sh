#!/usr/bin/env bash

# CIS 1.4: Ensure that the latest Cassandra version is installed
audit_1_4() {
    local CHECK_ID="1.4"
    local TITLE="Latest Cassandra version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Cassandra 4.0.x"
    local REMEDIATION="Upgrade Cassandra to the latest stable 4.0.x release."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(cassandra -v 2>/dev/null | head -n 1)
    [[ -z "$current_val" ]] && current_val="Not Installed"

    if [[ "$current_val" == 4.0.* ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    return 1
}

harden_1_4() {
    sudo apt-get update -y > /dev/null
    sudo apt-get install --only-upgrade cassandra -y
}

verify_1_4() {
    if ! audit_1_4 > /dev/null 2>&1; then
        harden_1_4
        audit_1_4
    else
        audit_1_4
    fi
}
