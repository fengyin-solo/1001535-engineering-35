#!/usr/bin/env bash
# 后端启动脚本：确保依赖就绪后用 uvicorn 拉起服务。
# 重复执行不会重装依赖（requirements.txt 没变就跳过）。
set -euo pipefail
cd "$(dirname "$0")"

# 端口等配置统一从仓库根目录的 .env 读，没有就用默认值
ROOT_ENV="../.env"
if [ -f "$ROOT_ENV" ]; then
  set -a; . "$ROOT_ENV"; set +a
fi
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"

fail() {
  echo "[backend] 启动失败：$1" >&2
  exit 1
}

# 端口被占用时给出可读说明，而不是让 uvicorn 报一堆堆栈
if python3 - "$BACKEND_PORT" <<'PY' 2>/dev/null
import socket, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
then
  :
else
  fail "端口 ${BACKEND_PORT} 已被占用。请先停掉占用该端口的进程，或在 .env 里把 BACKEND_PORT 改成别的端口。"
fi

# .venv 存在但 python 不可用（比如从别的机器拷贝过来的），删掉重建
if [ -d .venv ] && [ ! -x .venv/bin/python ]; then
  echo "[backend] 检测到 .venv 已损坏（可能是在别的系统上创建的），正在重建…"
  rm -rf .venv
fi

if [ ! -d .venv ]; then
  echo "[backend] 首次运行，创建虚拟环境 .venv …"
  if ! python3 -m venv .venv; then
    rm -rf .venv
    fail "创建虚拟环境失败。Debian/Ubuntu 请先执行 sudo apt install python3-venv，其他系统请确认 python3 自带 ensurepip。"
  fi
fi

# requirements.txt 没变就跳过安装；变了才重装，装失败给出可读说明
STAMP=".venv/.requirements.installed"
if [ -f "$STAMP" ] && cmp -s requirements.txt "$STAMP"; then
  echo "[backend] 依赖已是最新，跳过安装。"
else
  echo "[backend] 安装/更新依赖…"
  if ! .venv/bin/python -m pip install -q -r requirements.txt; then
    fail "依赖安装失败：请检查网络能否访问 pypi.org，或确认 requirements.txt 中的版本在当前 Python 上可用。"
  fi
  cp requirements.txt "$STAMP"
fi

echo "[backend] 即将监听 http://${BACKEND_HOST}:${BACKEND_PORT} （健康检查 /api/health）"
exec .venv/bin/uvicorn app.main:app --host "$BACKEND_HOST" --port "$BACKEND_PORT"
