#!/usr/bin/env bash
audit_os_5() {
    # Kiểm tra cấu hình trong file limits.conf
    if grep -q "cassandra soft nofile 100000" /etc/security/limits.conf; then
        json_result "OS.5" "Max Open Files Limit" "PASS" "MEDIUM" "Configured" ">=100000" "" "OS Custom"
        return 0
    fi
    return 1
}
harden_os_5() {
    echo "cassandra soft nofile 100000" | sudo tee -a /etc/security/limits.conf
    echo "cassandra hard nofile 100000" | sudo tee -a /etc/security/limits.conf
}
verify_os_5() { if ! audit_os_5 >/dev/null 2>&1; then harden_os_5; audit_os_5; else audit_os_5; fi; }
