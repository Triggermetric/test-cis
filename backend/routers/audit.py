"""Audit endpoints."""
from __future__ import annotations
import asyncio
import json
import logging
from datetime import datetime, timezone
from functools import partial

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse

from models import AuditReport, ClusterAuditReport
from services import ssh_runner, audit_parser
from config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/audit", tags=["audit"])


def _audit_node(node: str, section: str) -> AuditReport:
    cmd = audit_parser.audit_command(section)
    result = ssh_runner.run(node, cmd)
    if not result.ok:
        logger.warning("Audit on %s returned exit %d", node, result.exit_code)
    return audit_parser.parse_report(result.stdout, node)


@router.get("/node/{node_ip}", response_model=AuditReport)
async def audit_node(
    node_ip: str,
    section: str = Query(default="all", description="CIS section or check id"),
) -> AuditReport:
    """Run audit on a single node."""
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Unknown node: {node_ip}")
    try:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, partial(_audit_node, node_ip, section))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/cluster", response_model=ClusterAuditReport)
async def audit_cluster(
    section: str = Query(default="all"),
) -> ClusterAuditReport:
    """Run audit on all nodes concurrently."""
    try:
        loop = asyncio.get_running_loop()
        tasks = [
            loop.run_in_executor(None, partial(_audit_node, node, section))
            for node in settings.node_ips
        ]
        reports: list[AuditReport] = await asyncio.gather(*tasks)
        return ClusterAuditReport(
            timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            nodes=list(reports),
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/stream/{node_ip}")
async def audit_stream(node_ip: str, section: str = Query(default="all")):
    """Stream audit progress as Server-Sent Events."""
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Unknown node: {node_ip}")
    try:
        audit_parser.audit_command(section)  # validate section early; result unused
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    async def _generate():
        yield "data: " + json.dumps({"status": "started", "node": node_ip}) + "\n\n"
        loop = asyncio.get_running_loop()
        try:
            report = await loop.run_in_executor(
                None, partial(_audit_node, node_ip, section)
            )
            yield "data: " + json.dumps(report.model_dump()) + "\n\n"
            yield "data: " + json.dumps({"status": "done"}) + "\n\n"
        except Exception as e:
            yield "data: " + json.dumps({"status": "error", "detail": str(e)}) + "\n\n"

    return StreamingResponse(_generate(), media_type="text/event-stream")
