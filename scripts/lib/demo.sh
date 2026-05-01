#!/usr/bin/env bash
# demo.sh — Reset to insecure defaults and attack simulation for live presentation
# FOR DEMO USE ONLY — DO NOT RUN IN PRODUCTION

_CQLSH_HOST="${CASSANDRA_HOST:-localhost}"

demo_reset() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  echo ""
  warn "╔══════════════════════════════════════════════════════════╗"
  warn "║  DEMO RESET: Reverting to insecure defaults              ║"
  warn "║  FOR DEMO USE ONLY — DO NOT RUN IN PRODUCTION            ║"
  warn "╚══════════════════════════════════════════════════════════╝"
  echo ""

  info "[1/5] Disabling authentication (AllowAllAuthenticator)..."
  sudo sed -i 's/^authenticator:.*/authenticator: AllowAllAuthenticator/' "$yaml"

  info "[2/5] Disabling authorization (AllowAllAuthorizer)..."
  sudo sed -i 's/^authorizer:.*/authorizer: AllowAllAuthorizer/' "$yaml"

  info "[3/5] Disabling inter-node encryption..."
  sudo sed -i 's/^[[:space:]]*internode_encryption:.*/    internode_encryption: none/' "$yaml"

  info "[4/5] Disabling client encryption..."
  sudo awk '
    /^client_encryption_options:/ { in_block=1 }
    in_block && /^[^ #]/ && !/^client_encryption_options:/ { in_block=0 }
    in_block && /enabled: true/ { sub(/enabled: true/, "enabled: false") }
    { print }
  ' "$yaml" | sudo tee "$yaml.tmp" > /dev/null && sudo mv "$yaml.tmp" "$yaml"

  info "[5/5] Disabling audit logging..."
  sudo awk '
    /^audit_logging_options:/ { in_block=1 }
    in_block && /^[^ #]/ && !/^audit_logging_options:/ { in_block=0 }
    in_block && /enabled: true/ { sub(/enabled: true/, "enabled: false") }
    { print }
  ' "$yaml" | sudo tee "$yaml.tmp" > /dev/null && sudo mv "$yaml.tmp" "$yaml"

  warn "Restarting Cassandra with insecure config (waiting 20s)..."
  sudo systemctl restart cassandra 2>/dev/null || true
  sleep 20

  info "Resetting cassandra role password to default (requires auth still active)..."
  # Try with CIS admin creds first, then with new cassandra creds
  local new_pass="${NEW_CASSANDRA_PASS:-N3wCassandra@99!}"
  local admin_user="${CIS_ADMIN_USER:-cis_admin}"
  local admin_pass="${CIS_ADMIN_PASS:-Adm1n@Secure99!}"
  if cqlsh "$_CQLSH_HOST" -u "${admin_user}" -p "${admin_pass}" \
      --connect-timeout=5 --request-timeout=10 \
      -e "ALTER ROLE cassandra WITH PASSWORD='cassandra';" 2>/dev/null; then
    success "  cassandra password reset to default via CIS admin"
  elif cqlsh "$_CQLSH_HOST" -u cassandra -p "${new_pass}" \
      --connect-timeout=5 --request-timeout=10 \
      -e "ALTER ROLE cassandra WITH PASSWORD='cassandra';" 2>/dev/null; then
    success "  cassandra password reset to default"
  else
    warn "  Could not reset password — may need manual reset after restart"
    warn "  Run: cqlsh -u <admin> -p <pass> -e \"ALTER ROLE cassandra WITH PASSWORD='cassandra';\""
  fi

  echo ""
  success "╔══════════════════════════════════════════════════════════╗"
  success "║  RESET COMPLETE: Cluster is now in INSECURE state        ║"
  success "╚══════════════════════════════════════════════════════════╝"
  echo ""
}

demo_attack() {
  echo ""
  warn "╔══════════════════════════════════════════════════════════╗"
  warn "║  ATTACK SIMULATION — FOR DEMO PURPOSES ONLY             ║"
  warn "╚══════════════════════════════════════════════════════════╝"
  echo ""
  local ATTACKS_SUCCEEDED=0
  local ATTACKS_BLOCKED=0
  local TOTAL_ATTACKS=4

  # Attack 1: Default credentials
  echo "┌─ Attack 1: Login with default credentials (cassandra/cassandra)"
  if cqlsh "$_CQLSH_HOST" -u cassandra -p cassandra \
      --connect-timeout=5 --request-timeout=5 \
      -e "DESC CLUSTER;" &>/dev/null; then
    echo "│  RESULT: ✅ SUCCEEDED — default credentials WORK   ← INSECURE"
    ATTACKS_SUCCEEDED=$(( ATTACKS_SUCCEEDED + 1 ))
  else
    echo "│  RESULT: ❌ BLOCKED  — default credentials rejected ← SECURE"
    ATTACKS_BLOCKED=$(( ATTACKS_BLOCKED + 1 ))
  fi
  echo ""

  # Attack 2: Plaintext client connection
  echo "┌─ Attack 2: Plaintext client connection on port 9042"
  if cqlsh "$_CQLSH_HOST" --no-ssl \
      --connect-timeout=5 --request-timeout=5 \
      -e "DESC CLUSTER;" &>/dev/null; then
    echo "│  RESULT: ✅ SUCCEEDED — plaintext connection WORKS   ← INSECURE"
    ATTACKS_SUCCEEDED=$(( ATTACKS_SUCCEEDED + 1 ))
  else
    echo "│  RESULT: ❌ BLOCKED  — plaintext connection rejected ← SECURE"
    ATTACKS_BLOCKED=$(( ATTACKS_BLOCKED + 1 ))
  fi
  echo ""

  # Attack 3: Unauthorised role creation (tests CassandraAuthorizer)
  echo "┌─ Attack 3: Unauthorised role creation without superuser (tests CIS 2.2 Authorizer)"
  # Try to create a backdoor role using anonymous/default connection
  if cqlsh "$_CQLSH_HOST" \
      --connect-timeout=5 --request-timeout=5 \
      -e "CREATE ROLE IF NOT EXISTS demo_backdoor WITH PASSWORD='hacked' AND LOGIN=TRUE;" \
      &>/dev/null; then
    echo "│  RESULT: ✅ SUCCEEDED — role creation without auth WORKS ← INSECURE"
    # Clean up the role if it was created
    cqlsh "$_CQLSH_HOST" \
      -e "DROP ROLE IF EXISTS demo_backdoor;" &>/dev/null || true
    ATTACKS_SUCCEEDED=$(( ATTACKS_SUCCEEDED + 1 ))
  else
    echo "│  RESULT: ❌ BLOCKED  — unauthorised role creation rejected ← SECURE"
    ATTACKS_BLOCKED=$(( ATTACKS_BLOCKED + 1 ))
  fi
  echo ""

  # Attack 4: Read auth table anonymously
  echo "┌─ Attack 4: Read sensitive auth table (system_auth.roles) anonymously"
  if cqlsh "$_CQLSH_HOST" \
      --connect-timeout=5 --request-timeout=5 \
      -e "SELECT * FROM system_auth.roles;" &>/dev/null; then
    echo "│  RESULT: ✅ SUCCEEDED — auth table readable w/o auth ← INSECURE"
    ATTACKS_SUCCEEDED=$(( ATTACKS_SUCCEEDED + 1 ))
  else
    echo "│  RESULT: ❌ BLOCKED  — auth table protected          ← SECURE"
    ATTACKS_BLOCKED=$(( ATTACKS_BLOCKED + 1 ))
  fi
  echo ""

  echo "══════════════════════════════════════════════════════════"
  echo "  Attack Results:"
  echo "  Attacks SUCCEEDED (insecure): ${ATTACKS_SUCCEEDED}/${TOTAL_ATTACKS}"
  echo "  Attacks BLOCKED   (secure):   ${ATTACKS_BLOCKED}/${TOTAL_ATTACKS}"
  echo ""
  if [ "${ATTACKS_SUCCEEDED}" -eq 0 ]; then
    success "  🔒 ALL ATTACKS BLOCKED — cluster is FULLY HARDENED"
  elif [ "${ATTACKS_BLOCKED}" -eq 0 ]; then
    warn "  ⚠️  ALL ATTACKS SUCCEEDED — cluster is FULLY INSECURE"
  else
    warn "  ⚠️  PARTIAL HARDENING — ${ATTACKS_BLOCKED}/${TOTAL_ATTACKS} controls active"
  fi
  echo "══════════════════════════════════════════════════════════"
  echo ""
}
