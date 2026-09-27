"""运行配置：端口、跨域、运行环境。

端口与前端来源优先读环境变量（与仓库根目录 .env 同名），
不设置时回落到默认值，保证手工启动行为不变。
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field


def _frontend_origins() -> list[str]:
    host = os.environ.get("FRONTEND_HOST", "127.0.0.1")
    port = os.environ.get("FRONTEND_PORT", "5173")
    origins = [f"http://{host}:{port}"]
    if host != "localhost":
        origins.append(f"http://localhost:{port}")
    return origins


@dataclass(frozen=True)
class Settings:
    app_name: str = "气象观测站网运维平台"
    env: str = field(default_factory=lambda: os.environ.get("APP_ENV", "local"))
    port: int = field(default_factory=lambda: int(os.environ.get("BACKEND_PORT", "8000")))
    allowed_origins: list[str] = field(default_factory=_frontend_origins)
    page_size_default: int = 20
    page_size_max: int = 200


settings = Settings()
