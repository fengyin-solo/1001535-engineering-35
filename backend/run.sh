#!/usr/bin/env bash
# 后端手工启动入口（README 中的方式仍然可用）：
#   cd backend && ./run.sh
# 与仓库根目录的 ./dev.sh 共用同一份配置与依赖指纹：
# 依赖描述文件没变就直接启动，不再每次重装；端口从 dev.config / 环境变量读取。
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck source=../scripts/dev-common.sh
source ../scripts/dev-common.sh

load_config
assert_port_free "$BACKEND_HOST" "$BACKEND_PORT" "后端 uvicorn"

install_backend_deps

export APP_ENV="${APP_ENV:-local}"
export APP_HOST="$BACKEND_HOST"
export APP_PORT="$BACKEND_PORT"
export APP_ALLOWED_ORIGINS="${APP_ALLOWED_ORIGINS:-http://127.0.0.1:$FRONTEND_PORT,http://localhost:$FRONTEND_PORT}"

exec .venv/bin/uvicorn app.main:app --host "$BACKEND_HOST" --port "$BACKEND_PORT"
