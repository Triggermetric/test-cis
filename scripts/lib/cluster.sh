#!/usr/bin/env bash
# cluster.sh — Unified cluster management (status, restart, deploy, recommendations)

# -- Cluster Health & Status --
cluster_status() {
  info "Checking Cassandra cluster health across all nodes..."
  local overall=0
  local labels=("node1" "node2" "node3")

  echo ""
  printf "%-8s %-16s %-10s %s\n" "LABEL" "IP/HOST" "STATUS" "NODETOOL STATE"
  echo "--------------------------------------------------------------"

  for i in "${!NODE_IPS[@]}"; do
    local node="${NODE_IPS[$i]}"
    local label="${labels[$i]}"
    local svc_state="unknown"
    local node_state="UNKNOWN"

    if ! ssh_run "$node" "echo ok" &>/dev/null; then
       svc_state="UNREACHABLE"
       overall=1
    else
       svc_state=$(ssh_run "$node" "sudo systemctl is-active cassandra")
       if [ "$svc_state" != "active" ]; then overall=1; fi
       node_state=$(ssh_run "$node" "nodetool status 2>/dev/null | awk '/^(U|D)(N|L|J|M).*${node}/{print \$1}'" || echo "??")
       [ "$node_state" != "UN" ] && overall=1
    fi

    local color_svc="$svc_state"
    if [ "$svc_state" = "active" ]; then color_svc="${GREEN}$svc_state${NC}"; elif [ "$svc_state" = "UNREACHABLE" ]; then color_svc="${RED}$svc_state${NC}"; else color_svc="${YELLOW}$svc_state${NC}"; fi
    local color_node="$node_state"
    if [ "$node_state" = "UN" ]; then color_node="${GREEN}$node_state${NC}"; else color_node="${RED}$node_state${NC}"; fi

    printf "%-8s %-16s %-10b %b\n" "$label" "$node" "$color_svc" "$color_node"
  done
  echo "--------------------------------------------------------------"
  if [ "$overall" -eq 0 ]; then success "Cluster is healthy."; else warn "Cluster has issues."; fi
  return "$overall"
}

# -- Internal Helpers --
_wait_for_node_up() {
  local target="$1" coord="$2"
  local timeout="${CIS_NODE_UP_TIMEOUT:-180}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local state=$(ssh_run "$coord" "nodetool status 2>/dev/null | awk '/^(U|D)(N|L|J|M).*${target}/{print \$1}'" || echo "")
    if [ "$state" = "UN" ]; then return 0; fi
    sleep 10; elapsed=$((elapsed + 10))
  done
  return 1
}

_deploy_toolkit() {
  local node="$1" lbl="${2:-}"
  info "[DEPLOY] Syncing CIS toolkit to ${node}..."
  ssh_run "$node" "rm -rf /tmp/cis-tool && mkdir -p /tmp/cis-tool"
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -r \
    "$SCRIPT_DIR/cis-tool.sh" "$SCRIPT_DIR/lib" "$SSH_USER@$node:/tmp/cis-tool/"
  ssh_run "$node" "sudo rm -rf /opt/cis && sudo mkdir -p /opt/cis && sudo cp /tmp/cis-tool/cis-tool.sh /opt/cis/ && sudo cp -r /tmp/cis-tool/lib /opt/cis/ && sudo find /opt/cis -type f -name '*.sh' -exec sed -i 's/\r$//' {} + && sudo chmod 755 /opt/cis/cis-tool.sh && sudo chmod -R a+rX /opt/cis/lib"
}

_check_manual_signals() {
  local node="$1"
  ssh_run "$node" "timedatectl status 2>/dev/null | grep -qi 'NTP service: active\|synchronized: yes'" && success "  NTP status: synchronized" || warn "  NTP status: manual review required"
  ssh_run "$node" "grep -A10 '^audit_logging_options:' /etc/cassandra/cassandra.yaml 2>/dev/null | grep -qi 'enabled: true'" && success "  Audit logging: enabled" || warn "  Audit logging: manual review required"
  ssh_run "$node" "sudo systemctl is-active cassandra 2>/dev/null | grep -qx active" && success "  Cassandra service: active" || warn "  Cassandra service: not active"
}

# -- Orchestration --
cluster_rolling_restart() {
  info "Starting rolling restart..."
  for i in "${!NODE_IPS[@]}"; do
    local node="${NODE_IPS[$i]}"
    info "  Restarting Node $((i+1)): $node"
    ssh_run "$node" "sudo nodetool drain; sudo systemctl restart cassandra"
    local coord="${NODE_IPS[0]}"; if [ "$i" -eq 0 ]; then coord="${NODE_IPS[1]:-${NODE_IPS[0]}}"; fi
    if ! _wait_for_node_up "$node" "$coord"; then error "Rolling restart failed at $node."; return 1; fi
    sleep 10
  done
  success "Rolling restart completed."
}

cluster_deploy() {
  info "Deploying CIS toolkit to all nodes..."
  local labels=("node1" "node2" "node3")
  for i in "${!NODE_IPS[@]}"; do
    _deploy_toolkit "${NODE_IPS[$i]}" "${labels[$i]}"
  done
}

cluster_recommendations() {
  cluster_deploy
  info "Applying automated recommendations (Full suite: Sections 1-5)..."
  for node in "${NODE_IPS[@]}"; do
    echo "--- Hardening Node: $node ---"
    # Section 1: Installation & NTP
    ssh_run "$node" "sudo bash /opt/cis/cis-tool.sh harden 1"
    # Section 2: Auth & Authz
    ssh_run "$node" "sudo bash /opt/cis/cis-tool.sh harden 2"
    # Section 3: Roles & Default Passwords
    ssh_run "$node" "sudo bash /opt/cis/cis-tool.sh harden 3"
    # Section 4: Auditing
    ssh_run "$node" "sudo bash /opt/cis/cis-tool.sh harden 4"
    # Section 5: Encryption (TLS)
    ssh_run "$node" "sudo bash /opt/cis/cis-tool.sh harden 5"
  done
  
  info "Checking manual recommendation signals & verification..."
  for node in "${NODE_IPS[@]}"; do
    echo "--- Node Status: $node ---"
    _check_manual_signals "$node"
  done
}
