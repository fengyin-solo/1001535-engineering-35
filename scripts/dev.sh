#!/usr/bin/env bash
# 一键启动本地开发环境：后端（含示例数据）+ 前端 dev server。
#
# - 端口与代理目标统一从根目录 .env 读（没有则先按 .env.example 生成）
# - 依赖只在首次或清单变化时安装，重复启动直接复用
# - 依赖装不上、端口被占用时给出可读说明
# - Ctrl+C 同时停止前后端
set -euo pipefail
cd "$(dirname "$0")/.."

say() { echo "[dev] $*"; }
fail() { echo "[dev] 启动失败：$1" >&2; exit 1; }

# ---- 配置：单一来源是根目录 .env ----
if [ ! -f .env ]; then
  cp .env.example .env
  say "未找到 .env，已按 .env.example 生成默认配置，可按需修改。"
fi
set -a; . ./.env; set +a
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_HOST="${FRONTEND_HOST:-127.0.0.1}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"

command -v python3 >/dev/null 2>&1 || fail "未找到 python3，请先安装 Python 3.10+。"
command -v npm >/dev/null 2>&1 || fail "未找到 npm，请先安装 Node.js（建议 20+）。"

port_free() {
  python3 - "$1" <<'PY'
import socket, sys
s = socket.socket()
# SO_REUSEADDR 让刚关闭、处于 TIME_WAIT 的端口不算被占用；
# 若有进程正在 LISTEN，bind 仍然会失败
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

port_free "$BACKEND_PORT" || fail "后端端口 ${BACKEND_PORT} 已被占用：请先停掉占用进程，或修改 .env 里的 BACKEND_PORT。"
port_free "$FRONTEND_PORT" || fail "前端端口 ${FRONTEND_PORT} 已被占用：请先停掉占用进程，或修改 .env 里的 FRONTEND_PORT。"

# ---- 前端依赖：package.json / 锁文件没变就跳过安装 ----
STAMP="frontend/node_modules/.install-stamp"
fingerprint() { cat frontend/package.json frontend/package-lock.json 2>/dev/null | cksum; }
if [ -d frontend/node_modules ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$(fingerprint)" ]; then
  say "前端依赖已是最新，跳过安装。"
else
  say "安装前端依赖（首次或依赖清单有变化时）…"
  if ! (cd frontend && npm install --no-audit --no-fund); then
    fail "前端依赖安装失败：请检查网络能否访问 registry.npmjs.org，或删除 frontend/node_modules 后重试。"
  fi
  fingerprint > "$STAMP"
fi

# ---- 启动前后端，日志分别加 [backend]/[frontend] 前缀 ----
BACKEND_PID=""
FRONTEND_PID=""
STOPPING=""

kill_tree() {
  local pid="$1" child
  [ -n "$pid" ] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$child"; done
  kill "$pid" 2>/dev/null || true
}

cleanup() {
  [ -n "$STOPPING" ] && return 0
  STOPPING=1
  say "正在停止前后端进程…"
  kill_tree "$FRONTEND_PID"
  kill_tree "$BACKEND_PID"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prefix() {
  local tag="$1" line
  while IFS= read -r line; do
    # 子进程自己已带同样前缀的行（如 run.sh 输出的 [backend] …）不再重复添加
    case "$line" in
      "[$tag] "*) echo "$line" ;;
      *) echo "[$tag] $line" ;;
    esac
  done
}

say "启动后端（含示例数据）…"
( cd backend && exec ./run.sh ) > >(prefix backend) 2>&1 &
BACKEND_PID=$!

say "启动前端 dev server…"
( cd frontend && exec npm run dev ) > >(prefix frontend) 2>&1 &
FRONTEND_PID=$!

# ---- 等待后端就绪：健康检查通过，且示例数据与接口概览一致 ----
say "等待后端就绪（http://${BACKEND_HOST}:${BACKEND_PORT}）…"
backend_ready=""
for _ in $(seq 1 60); do
  kill -0 "$BACKEND_PID" 2>/dev/null || fail "后端进程提前退出，原因见上方 [backend] 日志。"
  if health=$(curl -sf "http://${BACKEND_HOST}:${BACKEND_PORT}/api/health" 2>/dev/null); then
    backend_ready=1
    break
  fi
  sleep 0.5
done
[ -n "$backend_ready" ] || fail "等待后端就绪超时（30 秒），原因见上方 [backend] 日志。"

modules=$(printf '%s' "$health" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("modules", "?"))')
overview_modules=$(curl -sf "http://${BACKEND_HOST}:${BACKEND_PORT}/api/overview" \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("modules", [])))')
if [ "$modules" = "$overview_modules" ]; then
  say "后端就绪：http://${BACKEND_HOST}:${BACKEND_PORT}（示例数据 ${modules} 个业务模块，与接口概览一致）"
else
  say "警告：示例数据模块数（${modules}）与接口概览（${overview_modules}）不一致，请检查 backend/app/seed.py"
fi

# ---- 等待前端就绪 ----
say "等待前端就绪（http://${FRONTEND_HOST}:${FRONTEND_PORT}）…"
frontend_ready=""
for _ in $(seq 1 60); do
  kill -0 "$FRONTEND_PID" 2>/dev/null || fail "前端进程提前退出，原因见上方 [frontend] 日志。"
  if curl -sf -o /dev/null "http://${FRONTEND_HOST}:${FRONTEND_PORT}/" 2>/dev/null; then
    frontend_ready=1
    break
  fi
  sleep 0.5
done
[ -n "$frontend_ready" ] || fail "等待前端就绪超时（30 秒），原因见上方 [frontend] 日志。"

say "前端就绪：http://${FRONTEND_HOST}:${FRONTEND_PORT}（/api 已代理到 http://${BACKEND_HOST}:${BACKEND_PORT}）"
say "全部就绪，浏览器打开上面的前端地址即可；Ctrl+C 可同时停止前后端。"

# ---- 任一进程退出则收尾 ----
while kill -0 "$BACKEND_PID" 2>/dev/null && kill -0 "$FRONTEND_PID" 2>/dev/null; do
  sleep 1
done
say "检测到进程退出，正在停止其余进程…"
exit 1
