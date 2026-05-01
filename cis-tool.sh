#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/scripts/lib/common.sh"

MODE=""
SECTION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --audit) MODE="audit"; shift ;;
    --harden) MODE="harden"; shift ;;
    --section) SECTION="$2"; shift 2 ;;
    *) log_err "Tham số không hợp lệ: $1"; exit 1 ;;
  esac
done

if [[ -z "$MODE" ]]; then
    log_err "Vui lòng chỉ định mode: --audit hoặc --harden"
    exit 1
fi

check_root

RESULTS_FILE="/tmp/cis_results.json"
> "$RESULTS_FILE"

log_info "=========================================="
log_info "CIS Cassandra Benchmark Tool v1.0"
log_info "Mode: $(echo $MODE | tr '[:lower:]' '[:upper:]')"
[[ -n "$SECTION" ]] && log_info "Section: $SECTION"
log_info "=========================================="

SEARCH_DIR="$DIR/scripts/sections"
if [[ -n "$SECTION" ]]; then
    SEARCH_DIR=$(find "$DIR/scripts/sections" -type d -name "${SECTION}_*")
    [[ -z "$SEARCH_DIR" ]] && { log_err "Không tìm thấy section $SECTION"; exit 1; }
fi

FAIL_COUNT=0
for script in $(find "$SEARCH_DIR" -name "check_*.sh" | sort); do
    source "$script"
    check_num=$(basename "$script" .sh | sed 's/check_//')
    
    if [[ "$MODE" == "audit" ]]; then
        audit_${check_num} >> "$RESULTS_FILE"
        if tail -n 1 "$RESULTS_FILE" | grep -q '"status":"FAIL"'; then
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    elif [[ "$MODE" == "harden" ]]; then
        harden_${check_num}
    fi
done

if [[ "$MODE" == "audit" ]]; then
    REPORT_PATH="$DIR/scripts/reports/report.json"
    log_info "Đang tổng hợp Report..."
    build_report "$(hostname -I | awk '{print $1}')" "$RESULTS_FILE" > "$REPORT_PATH"
    log_ok "File report được lưu tại: $REPORT_PATH"
    cat "$REPORT_PATH"
    
    if [[ $FAIL_COUNT -gt 0 ]]; then
        log_warn "Có $FAIL_COUNT check FAIL. Exit code 1."
        exit 1
    else
        log_ok "Tất cả PASS. Exit code 0."
        exit 0
    fi
fi
