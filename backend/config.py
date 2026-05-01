"""Application settings loaded from environment / .env file."""
from __future__ import annotations
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    cis_ssh_key: str = Field("~/.ssh/cis_key", validation_alias="CIS_SSH_KEY")
    cis_ssh_user: str = Field("cassandra", validation_alias="CIS_SSH_USER")
    # Accepts comma-separated IPs from NODE_IPS env var
    node_ips_str: str = Field(
        "10.0.1.11,10.0.1.12,10.0.1.13",
        validation_alias="NODE_IPS",
    )
    # Cassandra cluster contact point (usually the first node or seed)
    cassandra_contact_point: str = Field(
        "localhost",
        validation_alias="CASSANDRA_CONTACT_POINT",
    )

    @property
    def node_ips(self) -> list[str]:
        return [ip.strip() for ip in self.node_ips_str.split(",") if ip.strip()]


settings = Settings()
