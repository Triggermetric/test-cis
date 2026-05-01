"""Integration tests for FastAPI endpoints (mocked SSH)."""
import json
from unittest.mock import patch

import pytest
from httpx import AsyncClient, ASGITransport

from main import app
from services.ssh_runner import SSHResult


MOCK_REPORT = {
    "node": "10.0.1.11",
    "timestamp": "2026-04-01T10:00:00Z",
    "score": {
        "total": 2, "automated": 2, "manual": 0,
        "passed": 1, "failed": 1, "needs_review": 0,
    },
    "checks": [
        {"id": "2.1", "title": "Auth enabled", "status": "PASS",
         "type": "automated", "section": "Auth",
         "evidence": "PasswordAuthenticator", "remediable": False},
        {"id": "2.2", "title": "Authz enabled", "status": "FAIL",
         "type": "automated", "section": "Auth",
         "evidence": "AllowAllAuthorizer", "remediable": True},
    ],
}


def _mock_ssh_success(stdout: str) -> SSHResult:
    return SSHResult(stdout=stdout, stderr="", exit_code=0)


def _mock_ssh_fail() -> SSHResult:
    return SSHResult(stdout="", stderr="SSH connection failed", exit_code=255)


@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


# ── Health ────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_health(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_root(client):
    r = await client.get("/")
    assert r.status_code == 200
    assert "docs" in r.json()


# ── Audit node ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_audit_node_success(client):
    with patch("services.ssh_runner.run",
               return_value=_mock_ssh_success(json.dumps(MOCK_REPORT))):
        r = await client.get("/api/audit/node/10.0.1.11")
    assert r.status_code == 200
    body = r.json()
    assert body["node"] == "10.0.1.11"
    assert body["score"]["total"] == 2
    assert len(body["checks"]) == 2


@pytest.mark.asyncio
async def test_audit_node_unknown_ip(client):
    r = await client.get("/api/audit/node/10.0.0.99")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_audit_node_ssh_failure(client):
    with patch("services.ssh_runner.run", return_value=_mock_ssh_fail()):
        r = await client.get("/api/audit/node/10.0.1.11")
    # Should still return 200 with empty error report (graceful degradation)
    assert r.status_code == 200
    body = r.json()
    assert body["score"]["total"] == 0
    assert body["error"] is not None


@pytest.mark.asyncio
async def test_audit_node_invalid_section(client):
    r = await client.get("/api/audit/node/10.0.1.11?section=all;cat /etc/passwd")
    assert r.status_code == 400


# ── Audit cluster ─────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_audit_cluster_success(client):
    with patch("services.ssh_runner.run",
               return_value=_mock_ssh_success(json.dumps(MOCK_REPORT))):
        r = await client.get("/api/audit/cluster")
    assert r.status_code == 200
    body = r.json()
    assert len(body["nodes"]) == 3
    assert "cluster_score" in body
    assert body["cluster_score"]["total"] == 6  # 2 checks × 3 nodes


# ── Harden node ───────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_harden_node_success(client):
    with patch("services.ssh_runner.run",
               return_value=SSHResult(stdout="[OK] Done", stderr="", exit_code=0)):
        r = await client.post(
            "/api/harden/node/10.0.1.11",
            json={"section": "2", "dry_run": True},
        )
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["node"] == "10.0.1.11"


@pytest.mark.asyncio
async def test_harden_node_unknown_ip(client):
    r = await client.post(
        "/api/harden/node/10.0.0.99",
        json={"section": "all"},
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_harden_node_injection(client):
    r = await client.post(
        "/api/harden/node/10.0.1.11",
        json={"section": "all && evil", "dry_run": False},
    )
    assert r.status_code == 400


# ── Cluster status ────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_cluster_status_reachable(client):
    with patch("services.ssh_runner.check_reachable", return_value=(True, 12.3)):
        with patch("services.ssh_runner.run",
                   return_value=SSHResult(stdout="active", stderr="", exit_code=0)):
            r = await client.get("/api/cluster/status")
    assert r.status_code == 200
    statuses = r.json()
    assert len(statuses) == 3
    assert all(s["reachable"] for s in statuses)
    assert all(s["cassandra_running"] for s in statuses)


@pytest.mark.asyncio
async def test_cluster_status_unreachable(client):
    with patch("services.ssh_runner.check_reachable", return_value=(False, None)):
        r = await client.get("/api/cluster/status")
    assert r.status_code == 200
    statuses = r.json()
    assert all(not s["reachable"] for s in statuses)
    assert all(not s["cassandra_running"] for s in statuses)
