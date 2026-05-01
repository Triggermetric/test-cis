#!/usr/bin/env bash

# CIS 1.2: Ensure that the latest Java version is installed
audit_1_2() {
    local CHECK_ID="1.2"
    local TITLE="Latest Java version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Java 11 or 8"
    local REMEDIATION="Install/Upgrade OpenJDK 11."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    [[ -z "$current_val" ]] && current_val="Not Installed"

    # Cassandra 4.0 officially supports Java 8 and 11.
    if [[ "$current_val" == "11."* ]] || [[ "$current_val" == "1.8."* ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "Java $current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "${current_val:-unknown}" "$EXPECTED" "$REMEDIATION" "$SECTION"
    return 1
}

harden_1_2() {
    sudo apt-get update -y > /dev/null
    sudo apt-get install openjdk-11-jre-headless -y
}

verify_1_2() {
    if ! audit_1_2 > /dev/null 2>&1; then
        harden_1_2
        audit_1_2
    else
        audit_1_2
    fi
}
