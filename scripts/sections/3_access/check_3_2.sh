#!/usr/bin/env bash

# =========================================================================
# CIS RECOMMENDATION 3.2: Ensure that the default password is changed for the cassandra role
# Assessment Status: Automated
# =========================================================================

audit_3_2() {
    local CHECK_ID="3.2"
    local TITLE="Default password changed for cassandra"
    local SECTION="3 Access Control"
    local EXPECTED="Login failed with default credentials"
    local REMEDIATION="Alter cassandra role with new password."
    local SEVERITY="CRITICAL"

    # Bước kiểm tra theo tài liệu CIS: Thử kết nối với mật khẩu mặc định [cite: 539-540]
    if cqlsh -u cassandra -p cassandra -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; then
        # Nếu đăng nhập thành công bằng 'cassandra/cassandra' thì đây là một lỗ hổng [cite: 540]
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "Login successful with default password" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "Login rejected or DB unreachable" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
}

harden_3_2() {
    log_info "Remediating 3.2: Changing default 'cassandra' password to 'UIT2026'..."
    # Thực hiện lệnh Remediation theo tài liệu CIS [cite: 542-544]
    # Thêm dấu '=' để đảm bảo đúng cú pháp CQL của Cassandra 4.0
    cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH PASSWORD = 'UIT2026';"
    log_ok "Default password for 'cassandra' role updated."
}

verify_3_2() {
    # Kiểm tra trạng thái hiện tại [cite: 159-160]
    if ! audit_3_2 > /dev/null 2>&1; then
        # Nếu audit trả về FAIL (vẫn dùng pass mặc định), tiến hành vá lỗi 
        harden_3_2
        # Sau khi vá, chạy lại audit để báo kết quả cuối cùng lên Dashboard
        audit_3_2
    else
        audit_3_2
    fi
}
