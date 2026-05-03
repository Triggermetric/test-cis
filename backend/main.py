"""CIS Cassandra Compliance Dashboard — FastAPI Application."""
from __future__ import annotations
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import audit, harden, cluster, demo, data

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="CIS Cassandra Compliance Dashboard",
    description=(
        "Real-time CIS Apache Cassandra 4.0 Benchmark v1.3.0 compliance auditing "
        "and automated remediation for a 3-node cluster."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(audit.router)
app.include_router(harden.router)
app.include_router(cluster.router)
app.include_router(demo.router)
app.include_router(data.router)


@app.get("/health")
@app.get("/api/health")
async def health() -> dict:
    return {"status": "ok", "service": "cis-cassandra-dashboard"}


@app.get("/")
async def root() -> dict:
    return {
        "service": "CIS Cassandra Compliance Dashboard",
        "docs": "/docs",
        "health": "/health",
    }
