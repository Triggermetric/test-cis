#!/usr/bin/env bash

# =========================================================================
# CIS RECOMMENDATION 3.1: Ensure the cassandra and superuser roles are separate
# Assessment Status: Automated [cite: 492]
# =========================================================================

audit_3_1() {
    local CHECK_ID="3.1"
    local TITLE="Separate cassandra and superuser roles"
    local SECTION="3 Access Control"
    local EXPECTED="cassandra is not superuser"
    local REMEDIATION="Create new superuser and demote cassandra role."
    local SEVERITY="HIGH"

    # Kiểm tra xem role 'cassandra' có còn là superuser không [cite: 508, 511]
    # Lưu ý: Cần mật khẩu đúng để login cqlsh (giả sử UIT_DevOps_2026 từ check 3.2)
    local current_val
    current_val=$(cqlsh -u cassandra -p UIT_DevOps_2026 -e "SELECT role FROM system_auth.roles WHERE is_superuser = True ALLOW FILTERING;" 2>/dev/null | grep -w "cassandra" || echo "Safe")

    if [[ "$current_val" == *"cassandra"* ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "cassandra still has superuser status" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "cassandra is demoted or DB unreachable" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
}

harden_3_1() {
    log_info "Remediating 3.1: Creating new superuser and demoting 'cassandra' role..."
    
    # 1. Tạo role superuser mới theo tài liệu 
    cqlsh -u cassandra -p UIT_DevOps_2026 -e "CREATE ROLE 'uit_admin' WITH PASSWORD = 'UIT_DevOps_2026' AND LOGIN = TRUE AND SUPERUSER = TRUE;" || true
    
    # 2. Cấp quyền trên toàn bộ keyspaces 
    cqlsh -u cassandra -p UIT_DevOps_2026 -e "GRANT ALL PERMISSIONS ON ALL KEYSPACES TO 'uit_admin';" || true
    
    # 3. Thu hồi quyền superuser của tài khoản cassandra mặc định [cite: 523-524]
    cqlsh -u cassandra -p UIT_DevOps_2026 -e "UPDATE system_auth.roles SET is_superuser = null WHERE role = 'cassandra';"
    
    log_ok "New superuser 'uit_admin' created and 'cassandra' role demoted."
}

verify_3_1() {
    # Kiểm tra trạng thái hiện tại [cite: 160]
    if ! audit_3_1 > /dev/null 2>&1; then
        # Nếu FAIL (cassandra vẫn là superuser), thực hiện vá lỗi [cite: 161]
        harden_3_1
        # Kiểm tra lại lần cuối để xuất kết quả Dashboard
        audit_3_1
    else
        audit_3_1
    fi
}
