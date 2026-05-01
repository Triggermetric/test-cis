#!/usr/bin/env bash

# OS.3: Disable SSH Root Login
audit_os_3() {
    local CHECK_ID="OS.3"
    local TITLE="Disable SSH Root Login"
    local SECTION="OS Custom"
    local EXPECTED="no"
    local SEVERITY="HIGH"

    # Check effective SSH configuration
    local current_val=$(sshd -T 2>/dev/null | grep -i '^permitrootlogin' | awk '{print $2}')
    
    # Fallback to reading the file directly if sshd -T fails
    if [[ -z "$current_val" ]]; then
        current_val=$(grep -i '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}')
    fi

    if [[ "${current_val,,}" == "no" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "" "$SECTION"
        return 0
    fi
    
    json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "${current_val:-unknown}" "$EXPECTED" "Set PermitRootLogin to no" "$SECTION"
    return 1
}

harden_os_3() {
    # 1. Replace existing configuration or commented out configuration
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    
    # 2. If it wasn't in the file at all, append it
    if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    fi
    
    # 3. Restart SSH service to apply changes (handles both Debian and RHEL service names)
    sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null
}

verify_os_3() {
    if ! audit_os_3 > /dev/null 2>&1; then
        harden_os_3
        audit_os_3
    else
        audit_os_3
    fi
}
