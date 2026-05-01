"""Hardening endpoints."""
from __future__ import annotations
import logging
from functools import partial
import asyncio

from fastapi import APIRouter, HTTPException

from models import HardenRequest, HardenResult
from services import ssh_runner, audit_parser
from config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/harden", tags=["harden"])


def _harden_node(node: str, req: HardenRequest) -> HardenResult:
    cmd = audit_parser.harden_command(req.section, req.dry_run)
    result = ssh_runner.run(node, cmd, timeout=300)
    return HardenResult(
        node=node,
        section=req.section,
        exit_code=result.exit_code,
        stdout=result.stdout,
        stderr=result.stderr,
        success=result.ok,
    )


@router.post("/node/{node_ip}", response_model=HardenResult)
async def harden_node(node_ip: str, req: HardenRequest) -> HardenResult:
    """Apply CIS hardening to a single node."""
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Unknown node: {node_ip}")
    try:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, partial(_harden_node, node_ip, req))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/cluster", response_model=list[HardenResult])
async def harden_cluster(req: HardenRequest) -> list[HardenResult]:
    """Apply CIS hardening to all nodes concurrently."""
    try:
        loop = asyncio.get_running_loop()
        tasks = [
            loop.run_in_executor(None, partial(_harden_node, node, req))
            for node in settings.node_ips
        ]
        return list(await asyncio.gather(*tasks))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
