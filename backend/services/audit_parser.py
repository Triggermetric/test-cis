"""Parse JSON output from cis-tool.sh audit into AuditReport models."""
from __future__ import annotations
import json
import logging
import re
import shlex
from datetime import datetime, timezone

from models import AuditReport, AuditScore, CheckResult

logger = logging.getLogger(__name__)

CIS_TOOL_PATH = "/opt/cis/cis-tool.sh"

_SAFE_SECTION = re.compile(r'^[a-zA-Z0-9._-]{1,64}$')


def _validate_section(section: str) -> str:
    s = section.strip()
    if not _SAFE_SECTION.match(s):
        raise ValueError(f"Invalid section identifier: {s!r}")
    return s


def parse_report(raw_json: str, node: str) -> AuditReport:
    """Parse raw JSON string from cis-tool.sh into an AuditReport."""
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as e:
        logger.error("Failed to parse audit JSON from %s: %s\nRaw: %s", node, e, raw_json[:500])
        return _empty_report(node, error=str(e))

    try:
        return AuditReport(
            node=data.get("node", node),
            timestamp=data.get("timestamp", _now()),
            score=AuditScore(**data["score"]),
            checks=[CheckResult(**c) for c in data.get("checks", [])],
        )
    except (KeyError, TypeError, ValueError) as e:
        logger.error("Schema mismatch in audit report from %s: %s", node, e)
        return _empty_report(node, error=str(e))


def _empty_report(node: str, error: str = "") -> AuditReport:
    return AuditReport(
        node=node,
        timestamp=_now(),
        score=AuditScore(total=0, automated=0, manual=0,
                         passed=0, failed=0, needs_review=0),
        checks=[],
        error=error if error else None,
    )


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def audit_command(section: str = "all") -> str:
    """Build the cis-tool.sh audit command for a given section."""
    section = _validate_section(section)
    return f"sudo {CIS_TOOL_PATH} audit {shlex.quote(section)}"


def harden_command(section: str = "all", dry_run: bool = False) -> str:
    """Build the cis-tool.sh harden command."""
    section = _validate_section(section)
    parts = ["sudo", CIS_TOOL_PATH, "harden", section]
    if dry_run:
        parts.append("--dry-run")
    return shlex.join(parts)
