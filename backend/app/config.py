"""运行配置：端口、跨域、运行环境。

本地开发时端口等参数由仓库根目录的 dev.config（经 dev.sh / run.sh）注入；
也可以直接用环境变量覆盖，便于在其他机器或 CI 里启动。
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _allowed_origins() -> list[str]:
    raw = os.environ.get("APP_ALLOWED_ORIGINS", "").strip()
    if raw:
        return [item.strip() for item in raw.split(",") if item.strip()]
    return [
        "http://127.0.0.1:5173",
        "http://localhost:5173",
    ]


@dataclass(frozen=True)
class Settings:
    app_name: str = "气象观测站网运维平台"
    env: str = field(default_factory=lambda: os.environ.get("APP_ENV", "local"))
    host: str = field(default_factory=lambda: os.environ.get("APP_HOST", "127.0.0.1"))
    port: int = field(default_factory=lambda: _env_int("APP_PORT", 8000))
    allowed_origins: list[str] = field(default_factory=_allowed_origins)
    page_size_default: int = 20
    page_size_max: int = 200


settings = Settings()
