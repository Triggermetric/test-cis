"""Cluster status endpoints."""
from __future__ import annotations
import asyncio
import logging
from functools import partial

from fastapi import APIRouter

from models import NodeStatus
from services import ssh_runner
from config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/cluster", tags=["cluster"])


def _check_node(ip: str) -> NodeStatus:
    reachable, latency = ssh_runner.check_reachable(ip)
    cassandra_running = False
    if reachable:
        result = ssh_runner.run(ip, "systemctl is-active cassandra 2>/dev/null", timeout=10)
        cassandra_running = result.stdout.strip() == "active"
    return NodeStatus(
        ip=ip,
        reachable=reachable,
        cassandra_running=cassandra_running,
        latency_ms=latency,
    )


@router.get("/status", response_model=list[NodeStatus])
async def cluster_status() -> list[NodeStatus]:
    """Get status of all cluster nodes concurrently."""
    loop = asyncio.get_running_loop()
    tasks = [
        loop.run_in_executor(None, partial(_check_node, ip))
        for ip in settings.node_ips
    ]
    return list(await asyncio.gather(*tasks))
