"""SSH runner service using paramiko."""
from __future__ import annotations
import os
import time
import logging
from dataclasses import dataclass

import paramiko

logger = logging.getLogger(__name__)

SSH_TIMEOUT = 15
SSH_CMD_TIMEOUT = 120  # audit can take up to 2 minutes


@dataclass
class SSHResult:
    stdout: str
    stderr: str
    exit_code: int

    @property
    def ok(self) -> bool:
        return self.exit_code == 0


def _get_client(host: str) -> paramiko.SSHClient:
    from config import settings  # local import avoids circular dep
    ssh_key = os.path.expanduser(settings.cis_ssh_key)
    ssh_user = settings.cis_ssh_user
    client = paramiko.SSHClient()
    # Accepted risk: lab environment only
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=host,
        username=ssh_user,
        key_filename=ssh_key,
        timeout=SSH_TIMEOUT,
        look_for_keys=False,
        allow_agent=False,
    )
    return client


def run(host: str, command: str, timeout: int = SSH_CMD_TIMEOUT) -> SSHResult:
    """Execute a command on a remote host via SSH and return the result."""
    try:
        client = _get_client(host)
        try:
            _, stdout, stderr = client.exec_command(command, timeout=timeout)
            out = stdout.read().decode("utf-8", errors="replace")
            err = stderr.read().decode("utf-8", errors="replace")
            code = stdout.channel.recv_exit_status()
            return SSHResult(stdout=out.strip(), stderr=err.strip(), exit_code=code)
        finally:
            client.close()
    except paramiko.AuthenticationException as e:
        logger.error("SSH auth failed for %s: %s", host, e)
        return SSHResult(stdout="", stderr=f"SSH auth failed: {e}", exit_code=255)
    except (paramiko.SSHException, OSError) as e:
        logger.error("SSH connection failed for %s: %s", host, e)
        return SSHResult(stdout="", stderr=f"SSH connection failed: {e}", exit_code=255)


def check_reachable(host: str) -> tuple[bool, float | None]:
    """Returns (reachable, latency_ms)."""
    t0 = time.monotonic()
    try:
        client = _get_client(host)
        client.close()
        latency = (time.monotonic() - t0) * 1000
        return True, round(latency, 1)
    except Exception:
        return False, None
