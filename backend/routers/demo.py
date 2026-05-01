"""Demo endpoints — pre-loaded audit reports for quick walkthroughs."""
from __future__ import annotations
import json
import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/demo", tags=["demo"])

# Load fixture data
FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


def _load_fixture(name: str) -> dict:
    """Load a JSON fixture file."""
    path = FIXTURES_DIR / f"{name}.json"
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"Fixture not found: {name}")
    try:
        with open(path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        logger.error("Failed to parse fixture %s: %s", name, e)
        raise HTTPException(status_code=500, detail="Invalid fixture data")


@router.get("/report/{scenario}")
async def demo_report(scenario: str) -> dict:
    """Return pre-computed demo audit report for quick walkthroughs.
    
    Scenarios:
    - baseline: Initial audit with ~73% compliance
    - hardened: After applying CIS hardening (~92% compliance)
    """
    scenarios = {
        "baseline": "baseline-audit",
        "hardened": "hardened-audit",
    }
    
    if scenario not in scenarios:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown scenario. Available: {', '.join(scenarios.keys())}",
        )
    
    fixture_name = scenarios[scenario]
    try:
        return _load_fixture(fixture_name)
    except HTTPException:
        # If hardened fixture doesn't exist, return baseline as fallback
        if scenario == "hardened":
            logger.warning("Hardened fixture not found, falling back to baseline")
            return _load_fixture("baseline-audit")
        raise


@router.get("/scenarios")
async def list_scenarios() -> dict:
    """List available demo scenarios."""
    return {
        "scenarios": [
            {
                "id": "baseline",
                "label": "Baseline Audit",
                "description": "Initial cluster scan (~73% compliant)",
            },
            {
                "id": "hardened",
                "label": "After Hardening",
                "description": "Post-remediation compliance (~92% compliant)",
            },
        ]
    }
