"""Pydantic models for CIS audit reports."""
from __future__ import annotations
from typing import Literal
from pydantic import BaseModel, Field, computed_field


class CheckResult(BaseModel):
    id: str
    title: str
    status: Literal["PASS", "FAIL", "NEEDS_REVIEW"]
    type: Literal["automated", "manual"]
    section: str
    evidence: str = ""
    remediable: bool = False


class AuditScore(BaseModel):
    total: int
    automated: int
    manual: int
    passed: int
    failed: int
    needs_review: int

    @computed_field
    @property
    def compliance_pct(self) -> float:
        if self.total == 0:
            return 0.0
        return round(self.passed / self.total * 100, 1)


class AuditReport(BaseModel):
    node: str
    timestamp: str
    score: AuditScore
    checks: list[CheckResult] = Field(default_factory=list)
    error: str | None = None


class ClusterAuditReport(BaseModel):
    timestamp: str
    nodes: list[AuditReport] = Field(default_factory=list)

    @computed_field
    @property
    def cluster_score(self) -> AuditScore:
        if not self.nodes:
            return AuditScore(total=0, automated=0, manual=0,
                              passed=0, failed=0, needs_review=0)
        totals = {
            "total": sum(n.score.total for n in self.nodes),
            "automated": sum(n.score.automated for n in self.nodes),
            "manual": sum(n.score.manual for n in self.nodes),
            "passed": sum(n.score.passed for n in self.nodes),
            "failed": sum(n.score.failed for n in self.nodes),
            "needs_review": sum(n.score.needs_review for n in self.nodes),
        }
        return AuditScore(**totals)


class HardenRequest(BaseModel):
    section: str = "all"
    dry_run: bool = False


class HardenResult(BaseModel):
    node: str
    section: str
    exit_code: int
    stdout: str
    stderr: str
    success: bool


class NodeStatus(BaseModel):
    ip: str
    reachable: bool
    cassandra_running: bool
    latency_ms: float | None = None
