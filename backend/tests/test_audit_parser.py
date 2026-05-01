"""Unit tests for audit_parser service."""
import json
import pytest
from services.audit_parser import parse_report, audit_command, harden_command, _validate_section

GOOD_JSON = json.dumps({
    "node": "10.0.1.11",
    "timestamp": "2026-04-01T10:00:00Z",
    "score": {
        "total": 2, "automated": 2, "manual": 0,
        "passed": 1, "failed": 1, "needs_review": 0,
    },
    "checks": [
        {"id": "2.1", "title": "Auth", "status": "PASS",
         "type": "automated", "section": "Auth",
         "evidence": "ok", "remediable": False},
    ],
})


def test_parse_report_valid():
    r = parse_report(GOOD_JSON, "10.0.1.11")
    assert r.node == "10.0.1.11"
    assert r.score.total == 2
    assert len(r.checks) == 1
    assert r.error is None


def test_parse_report_invalid_json():
    r = parse_report("{not valid json}", "10.0.1.11")
    assert r.score.total == 0
    assert r.error is not None
    assert len(r.checks) == 0


def test_parse_report_missing_score_key():
    bad = json.dumps({"node": "10.0.1.11", "timestamp": "t", "checks": []})
    r = parse_report(bad, "10.0.1.11")
    assert r.score.total == 0
    assert r.error is not None


def test_audit_command_default():
    cmd = audit_command()
    assert "cis-tool.sh" in cmd
    assert "audit" in cmd
    assert "all" in cmd


def test_audit_command_section():
    cmd = audit_command("2")
    assert "audit" in cmd
    assert "'2'" in cmd or " 2" in cmd


def test_audit_command_injection():
    with pytest.raises(ValueError):
        audit_command("all; cat /etc/passwd")


def test_audit_command_injection_ampersand():
    with pytest.raises(ValueError):
        audit_command("all && rm -rf /")


def test_harden_command_dry_run():
    cmd = harden_command("all", dry_run=True)
    assert "--dry-run" in cmd


def test_harden_command_no_dry_run():
    cmd = harden_command("all", dry_run=False)
    assert "--dry-run" not in cmd


def test_validate_section_valid():
    assert _validate_section("all") == "all"
    assert _validate_section("2.1") == "2.1"
    assert _validate_section("5") == "5"


def test_validate_section_invalid():
    with pytest.raises(ValueError):
        _validate_section("all; echo pwned")
    with pytest.raises(ValueError):
        _validate_section("")
    with pytest.raises(ValueError):
        _validate_section("a" * 65)  # too long
