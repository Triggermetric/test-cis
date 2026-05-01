#!/usr/bin/env bash

# CIS 1.3: Ensure that the latest Python version is installed (Required for CQLSH)
audit_1_3() {
    local CHECK_ID="1.3"
    local TITLE="Latest Python version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Python 3.x"
    local REMEDIATION="Install/Upgrade Python 3."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(python3 -V 2>&1 | awk '{print $2}')
    [[ -z "$current_val" ]] && current_val="Not Installed"

    # CQLSH in Cassandra 4.0 relies on Python 3
    if [[ "$current_val" == "3."* ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "Python $current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "${current_val:-unknown}" "$EXPECTED" "$REMEDIATION" "$SECTION"
    return 1
}

harden_1_3() {
    sudo apt-get update -y > /dev/null
    sudo apt-get install python3 -y
}

verify_1_3() {
    if ! audit_1_3 > /dev/null 2>&1; then
        harden_1_3
        audit_1_3
    else
        audit_1_3
    fi
}
