#!/usr/bin/env bash
audit_5_1() {
    # Kiểm tra config trong file cassandra.yaml [cite: 819-821]
    local val=$(grep "^internode_encryption:" /etc/cassandra/cassandra.yaml | awk '{print $2}')
    if [[ "$val" == "all" || "$val" == "dc" ]]; then
        json_result "5.1" "Inter-node Encryption" "PASS" "HIGH" "$val" "all/dc" "" "5 Encryption"
        return 0
    fi
    return 1
}
harden_5_1() {
    # Xây dựng Keystore và bật encryption theo tài liệu [cite: 826-830]
    sudo mkdir -p /etc/cassandra/certs
    [ ! -f /etc/cassandra/certs/keystore.jks ] && sudo keytool -genkey -noprompt -keyalg RSA -alias cassandra -keystore /etc/cassandra/certs/keystore.jks -storepass cassandra -keypass cassandra -validity 360 -dname "CN=$(hostname)" > /dev/null 2>&1
    sudo chown cassandra:cassandra /etc/cassandra/certs/keystore.jks
    sudo sed -i 's/internode_encryption: none/internode_encryption: all/' /etc/cassandra/cassandra.yaml
}
verify_5_1() { if ! audit_5_1 >/dev/null 2>&1; then harden_5_1; audit_5_1; else audit_5_1; fi; }
