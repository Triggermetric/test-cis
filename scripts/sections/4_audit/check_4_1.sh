#!/usr/bin/env bash

audit_4_1() {
    # Check thẳng file cấu hình.
    if grep -q '<root level="INFO">' /etc/cassandra/logback.xml; then
        json_result "4.1" "Logging is enabled" "PASS" "LOW" "Level: INFO" "Not OFF" "" "4 Logging"
        return 0
    fi
    
    # ép báo lỗi
    json_result "4.1" "Logging is enabled" "FAIL" "LOW" "Level: OFF" "Not OFF" "" "4 Logging"
    return 1
}

harden_4_1() {
    # Ghi đè trực tiếp
    sudo sed -i 's/<root level="OFF">/<root level="INFO">/g' /etc/cassandra/logback.xml
}

verify_4_1() {
    if ! audit_4_1 > /dev/null 2>&1; then
        harden_4_1
        audit_4_1
    else
        audit_4_1
    fi
}
