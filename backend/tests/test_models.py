"""Unit tests for Pydantic models."""
import pytest
from models import (
    CheckResult, AuditScore, AuditReport, ClusterAuditReport,
    HardenRequest, NodeStatus
)


# ── CheckResult ─────────────────────────────────────────────────────────────

def test_check_result_pass():
    c = CheckResult(
        id="2.1", title="Auth", status="PASS",
        type="automated", section="Auth", evidence="ok"
    )
    assert c.status == "PASS"
    assert c.remediable is False


def test_check_result_fail_remediable():
    c = CheckResult(
        id="2.1", title="Auth", status="FAIL",
        type="automated", section="Auth", remediable=True
    )
    assert c.remediable is True


def test_check_result_invalid_status():
    with pytest.raises(Exception):
        CheckResult(id="x", title="t", status="UNKNOWN",
                    type="automated", section="s")


# ── AuditScore ───────────────────────────────────────────────────────────────

def test_audit_score_compliance_pct():
    s = AuditScore(total=20, automated=12, manual=8,
                   passed=15, failed=3, needs_review=2)
    assert s.compliance_pct == 75.0


def test_audit_score_compliance_pct_zero_total():
    s = AuditScore(total=0, automated=0, manual=0,
                   passed=0, failed=0, needs_review=0)
    assert s.compliance_pct == 0.0


def test_audit_score_included_in_model_dump():
    """compliance_pct must appear in serialised output (computed_field)."""
    s = AuditScore(total=4, automated=4, manual=0,
                   passed=3, failed=1, needs_review=0)
    d = s.model_dump()
    assert "compliance_pct" in d
    assert d["compliance_pct"] == 75.0


# ── AuditReport ──────────────────────────────────────────────────────────────

def test_audit_report_no_error():
    r = AuditReport(
        node="10.0.1.11",
        timestamp="2026-04-01T10:00:00Z",
        score=AuditScore(total=1, automated=1, manual=0,
                         passed=1, failed=0, needs_review=0),
    )
    assert r.error is None
    assert r.checks == []


def test_audit_report_with_error():
    r = AuditReport(
        node="10.0.1.11",
        timestamp="2026-04-01T10:00:00Z",
        score=AuditScore(total=0, automated=0, manual=0,
                         passed=0, failed=0, needs_review=0),
        error="JSON parse failed",
    )
    assert r.error == "JSON parse failed"


# ── ClusterAuditReport ───────────────────────────────────────────────────────

def test_cluster_score_aggregated():
    nodes = [
        AuditReport(
            node=f"10.0.1.1{i}",
            timestamp="2026-04-01T10:00:00Z",
            score=AuditScore(total=10, automated=8, manual=2,
                             passed=7, failed=2, needs_review=1),
        )
        for i in range(1, 4)
    ]
    cluster = ClusterAuditReport(timestamp="2026-04-01T10:00:00Z", nodes=nodes)
    s = cluster.cluster_score
    assert s.total == 30
    assert s.passed == 21
    assert s.failed == 6


def test_cluster_score_empty():
    cluster = ClusterAuditReport(timestamp="2026-04-01T10:00:00Z")
    s = cluster.cluster_score
    assert s.total == 0


def test_cluster_score_in_model_dump():
    """cluster_score must appear in serialised ClusterAuditReport."""
    cluster = ClusterAuditReport(
        timestamp="2026-04-01T10:00:00Z",
        nodes=[
            AuditReport(
                node="10.0.1.11",
                timestamp="2026-04-01T10:00:00Z",
                score=AuditScore(total=2, automated=2, manual=0,
                                 passed=2, failed=0, needs_review=0),
            )
        ],
    )
    d = cluster.model_dump()
    assert "cluster_score" in d
    assert d["cluster_score"]["total"] == 2


# ── HardenRequest / HardenResult ─────────────────────────────────────────────

def test_harden_request_defaults():
    r = HardenRequest()
    assert r.section == "all"
    assert r.dry_run is False


# ── NodeStatus ───────────────────────────────────────────────────────────────

def test_node_status_unreachable():
    n = NodeStatus(ip="10.0.1.11", reachable=False, cassandra_running=False)
    assert n.latency_ms is None
