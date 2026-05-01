#!/usr/bin/env bash

# CIS 1.6: Ensure that clocks are synchronized across the cluster
audit_1_6() {
    local CHECK_ID="1.6"
    local TITLE="Clocks are synchronized"
    local SECTION="1 Installation and Updates"
    local EXPECTED="NTP Active"
    local SEVERITY="HIGH"

    # Check if chrony or ntp service is active
    local ntp_status
    ntp_status=$(timedatectl status | grep "System clock synchronized" | awk '{print $4}')
    
    if [[ "$ntp_status" == "yes" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "NTP Synced" "$EXPECTED" "" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "NTP Not Synced" "$EXPECTED" "Install and enable chrony" "$SECTION"
    return 1
}

harden_1_6() {
    sudo apt-get update -y > /dev/null
    sudo apt-get install chrony -y
    
    sudo systemctl enable --now chrony
    
    # Force systemd to recognize NTP
    sudo timedatectl set-ntp true
}

verify_1_6() {
    if ! audit_1_6 > /dev/null 2>&1; then
        harden_1_6
        audit_1_6
    else
        audit_1_6
    fi
}
