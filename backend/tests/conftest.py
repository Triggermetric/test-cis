"""pytest configuration and shared fixtures."""
import sys
import os
import json

import pytest
from httpx import AsyncClient, ASGITransport

# Ensure backend/ is on the path so `from models import` etc. resolves
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from main import app

SAMPLE_REPORT = {
    "node": "10.0.1.11",
    "timestamp": "2026-04-01T10:00:00Z",
    "score": {
        "total": 20,
        "automated": 12,
        "manual": 8,
        "passed": 15,
        "failed": 3,
        "needs_review": 2,
    },
    "checks": [
        {
            "id": "2.1",
            "title": "Ensure authentication is enabled",
            "status": "PASS",
            "type": "automated",
            "section": "Auth",
            "evidence": "authenticator: PasswordAuthenticator",
            "remediable": False,
        },
        {
            "id": "2.2",
            "title": "Ensure authorizer is enabled",
            "status": "FAIL",
            "type": "automated",
            "section": "Auth",
            "evidence": "authorizer: AllowAllAuthorizer",
            "remediable": True,
        },
    ],
}


@pytest.fixture
def sample_report_json():
    return json.dumps(SAMPLE_REPORT)


@pytest.fixture
async def async_client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client
