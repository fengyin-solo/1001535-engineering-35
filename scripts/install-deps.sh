#!/usr/bin/env bash
# 一次性安装前端与后端依赖（按锁文件，跨机器版本一致）：
#   ./scripts/install-deps.sh    或    make install
# 依赖描述文件没变时重复执行会跳过安装；如需强制重装，删除对应 .venv / node_modules 即可。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=dev-common.sh
source "$SCRIPT_DIR/dev-common.sh"

check_tools
log "安装/校验后端与前端依赖（锁文件版本，未变化则跳过）"
install_backend_deps
install_frontend_deps
ok "依赖已就绪：后端 backend/.venv，前端 frontend/node_modules"
