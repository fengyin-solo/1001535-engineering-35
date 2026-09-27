#!/usr/bin/env bash
# 一条命令拉起本地开发链路：后端（含示例数据）+ 前端（代理指向后端）。
#   ./dev.sh
# 首次运行会自动安装两边依赖（按锁文件）；之后重复启动指纹不变则直接跳过安装。
# 端口与代理目标统一在仓库根目录的 dev.config 中配置。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/dev-common.sh
source "$SCRIPT_DIR/scripts/dev-common.sh"

load_config
check_tools

log "气象观测站网运维平台 · 本地开发"
log "后端：http://$BACKEND_HOST:$BACKEND_PORT（健康检查 /api/health）"
log "前端：http://$FRONTEND_HOST:$FRONTEND_PORT（/api 代理到 $VITE_PROXY_TARGET）"

assert_port_free "$BACKEND_HOST" "$BACKEND_PORT" "后端 uvicorn"
assert_port_free "$FRONTEND_HOST" "$FRONTEND_PORT" "前端 vite dev server"

install_backend_deps
install_frontend_deps

BACKEND_PID=""
FRONTEND_PID=""
STOPPING=0

cleanup() {
  trap - INT TERM EXIT
  STOPPING=1
  [ -n "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null
  # 等真实服务进程退出，避免 Ctrl-C 后端口来不及释放
  local waited=0
  while { [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; } \
     || { [ -n "$FRONTEND_PID" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; }; do
    [ "$waited" -ge 5 ] && break
    sleep 1
    waited=$((waited + 1))
  done
  log "已停止前端与后端，再见"
}
trap cleanup INT TERM EXIT

# 给子进程输出加前缀，日志里能分清是前端还是后端
prefix_output() {
  local tag="$1"
  if [ -t 1 ]; then
    while IFS= read -r line; do printf '\033[0;35m[%s]\033[0m %s\n' "$tag" "$line"; done
  else
    while IFS= read -r line; do printf '[%s] %s\n' "$tag" "$line"; done
  fi
}

# wait_for_ready <名称> <host> <port> <路径> <健康关键字或-> <最长秒数>
wait_for_ready() {
  local name="$1" host="$2" port="$3" path="$4" keyword="$5" timeout_s="$6"
  local check_host="$host"
  [ "$check_host" = "0.0.0.0" ] && check_host="127.0.0.1"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout_s" ]; do
    # 收到收尾信号时不再把服务退出误判成「提前退出」
    [ "$STOPPING" -eq 1 ] && exit 0
    if ! kill -0 "$BACKEND_PID" 2>/dev/null && [ "$name" = "后端" ]; then
      die "后端进程已提前退出，请查看上方 [backend] 日志定位原因"
    fi
    if ! kill -0 "$FRONTEND_PID" 2>/dev/null && [ "$name" = "前端" ]; then
      die "前端进程已提前退出，请查看上方 [frontend] 日志定位原因"
    fi
    if python3 - "$check_host" "$port" "$path" "$keyword" <<'PYEOF' 2>/dev/null
import sys, urllib.request
host, port, path, keyword = sys.argv[1:5]
try:
    with urllib.request.urlopen(f"http://{host}:{port}{path}", timeout=1) as resp:
        body = resp.read().decode("utf-8", "replace")
    if keyword in ("-", "") or keyword in body:
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
PYEOF
    then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  die "$name 在 ${timeout_s} 秒内没有就绪（http://$check_host:$port$path 无响应），请查看上方日志"
}

log "启动后端（示例数据在服务启动时自动载入内存）"
# 用进程替换而不是管道：这样 $! 是服务自身的 PID（子 shell 经 exec 成为 uvicorn），
# 否则管道下 $! 只是日志格式化进程，Ctrl-C 时杀不掉真正的服务。
(
  cd "$SCRIPT_DIR/backend"
  exec env \
    APP_ENV="${APP_ENV:-local}" \
    APP_HOST="$BACKEND_HOST" APP_PORT="$BACKEND_PORT" \
    APP_ALLOWED_ORIGINS="http://127.0.0.1:$FRONTEND_PORT,http://localhost:$FRONTEND_PORT" \
    .venv/bin/uvicorn app.main:app --host "$BACKEND_HOST" --port "$BACKEND_PORT"
) > >(prefix_output "backend") 2>&1 &
BACKEND_PID=$!

wait_for_ready "后端" "$BACKEND_HOST" "$BACKEND_PORT" /api/health '"ok":true' 30
backend_info="$("$SCRIPT_DIR/backend/.venv/bin/python" - "$BACKEND_HOST" "$BACKEND_PORT" <<'PYEOF' 2>/dev/null
import json, sys, urllib.request
host, port = sys.argv[1:3]
with urllib.request.urlopen(f"http://{host}:{port}/api/health", timeout=2) as resp:
    data = json.load(resp)
print(f"健康检查通过，已载入 {data.get('modules')} 个业务模块的示例数据")
PYEOF
)"
ok "后端已就绪：http://$BACKEND_HOST:$BACKEND_PORT（${backend_info:-健康检查通过}）"

log "启动前端 dev server"
(
  cd "$SCRIPT_DIR/frontend"
  exec env \
    VITE_PROXY_TARGET="$VITE_PROXY_TARGET" \
    FRONTEND_HOST="$FRONTEND_HOST" \
    FRONTEND_PORT="$FRONTEND_PORT" \
    node_modules/.bin/vite
) > >(prefix_output "frontend") 2>&1 &
FRONTEND_PID=$!

wait_for_ready "前端" "$FRONTEND_HOST" "$FRONTEND_PORT" / - 30
ok "前端已就绪：http://$FRONTEND_HOST:$FRONTEND_PORT（页面中的 /api 请求会代理到 $VITE_PROXY_TARGET）"
log "两个服务均已就绪，浏览器访问 http://$FRONTEND_HOST:$FRONTEND_PORT 即可；按 Ctrl-C 一并停止"

# 任一服务退出就收尾，避免留下半个环境（正常 Ctrl-C 收尾时不再重复告警）
if [ "$STOPPING" -eq 0 ]; then
  wait -n "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null
  warn "有服务提前退出，准备停止整套开发环境"
  cleanup
fi
