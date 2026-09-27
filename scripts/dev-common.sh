#!/usr/bin/env bash
# dev.sh / backend/run.sh / scripts/install-deps.sh 共用的工具函数。
# 只依赖 bash 3.2+ 自带能力与 python3/node，macOS 自带环境也能直接跑。

# 仓库根目录（本文件位于 <root>/scripts/ 下）
DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_CONFIG_FILE="$DEV_ROOT/dev.config"
LOCK_STAMP_DIR="$DEV_ROOT/.dev-stamps"

# 终端有颜色时才上色，重定向到文件/CI 时不输出转义码
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_INFO='\033[0;36m'; C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_ERR='\033[0;31m'; C_RESET='\033[0m'
else
  C_INFO=''; C_OK=''; C_WARN=''; C_ERR=''; C_RESET=''
fi

log()  { printf "%b[dev]%b %s\n" "$C_INFO" "$C_RESET" "$*"; }
ok()   { printf "%b[ok]%b  %s\n" "$C_OK" "$C_RESET" "$*"; }
warn() { printf "%b[warn]%b %s\n" "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf "%b[错误]%b %s\n" "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }

# load_config：先读 dev.config，再允许同名环境变量覆盖，最后填默认值。
load_config() {
  # 保存环境变量中的显式取值（优先级：环境变量 > dev.config > 默认值）
  local env_backend_host="${BACKEND_HOST-}"
  local env_backend_port="${BACKEND_PORT-}"
  local env_frontend_host="${FRONTEND_HOST-}"
  local env_frontend_port="${FRONTEND_PORT-}"
  local env_proxy_target="${VITE_PROXY_TARGET-}"

  BACKEND_HOST="127.0.0.1"
  BACKEND_PORT="8000"
  FRONTEND_HOST="127.0.0.1"
  FRONTEND_PORT="5173"
  VITE_PROXY_TARGET=""

  if [ -f "$DEV_CONFIG_FILE" ]; then
    # 只认 KEY=VALUE 形式，跳过注释与空行
    while IFS='=' read -r key value || [ -n "$key" ]; do
      case "$key" in
        ''|\#*) continue ;;
      esac
      key="${key#"${key%%[![:space:]]*}"}"
      value="${value%${value##*[![:space:]]}}"
      # 去掉行尾注释（形如 "VALUE # 注释"）；带引号的值不去
      case "$value" in
        '"'*) value="${value#\"}"; value="${value%\"}" ;;
        *) value="${value%%[[:space:]]#*}"; value="${value%"${value##*[![:space:]]}"}" ;;
      esac
      case "$key" in
        BACKEND_HOST) BACKEND_HOST="$value" ;;
        BACKEND_PORT) BACKEND_PORT="$value" ;;
        FRONTEND_HOST) FRONTEND_HOST="$value" ;;
        FRONTEND_PORT) FRONTEND_PORT="$value" ;;
        VITE_PROXY_TARGET) VITE_PROXY_TARGET="$value" ;;
      esac
    done < "$DEV_CONFIG_FILE"
  fi

  # 环境变量非空时覆盖配置文件（空字符串视为未提供）
  [ -n "$env_backend_host" ] && BACKEND_HOST="$env_backend_host"
  [ -n "$env_backend_port" ] && BACKEND_PORT="$env_backend_port"
  [ -n "$env_frontend_host" ] && FRONTEND_HOST="$env_frontend_host"
  [ -n "$env_frontend_port" ] && FRONTEND_PORT="$env_frontend_port"
  [ -n "$env_proxy_target" ] && VITE_PROXY_TARGET="$env_proxy_target"

  case "$BACKEND_PORT$FRONTEND_PORT" in
    ''|*[!0-9]*) die "dev.config 里的端口必须是数字，当前 BACKEND_PORT=$BACKEND_PORT FRONTEND_PORT=$FRONTEND_PORT" ;;
  esac
  if [ "$BACKEND_PORT" -lt 1 ] || [ "$BACKEND_PORT" -gt 65535 ] \
     || [ "$FRONTEND_PORT" -lt 1 ] || [ "$FRONTEND_PORT" -gt 65535 ]; then
    die "dev.config 里的端口必须在 1-65535 之间，当前 BACKEND_PORT=$BACKEND_PORT FRONTEND_PORT=$FRONTEND_PORT"
  fi
  if [ "$BACKEND_HOST" = "$FRONTEND_HOST" ] && [ "$BACKEND_PORT" = "$FRONTEND_PORT" ]; then
    die "前端与后端不能共用 $FRONTEND_HOST:$FRONTEND_PORT，请在 dev.config 里把 BACKEND_PORT / FRONTEND_PORT 改成不同端口"
  fi

  # 代理目标未显式配置时按后端地址推导
  if [ -z "$VITE_PROXY_TARGET" ]; then
    local_host="$BACKEND_HOST"
    [ "$local_host" = "0.0.0.0" ] && local_host="127.0.0.1"
    VITE_PROXY_TARGET="http://$local_host:$BACKEND_PORT"
  fi
  export BACKEND_HOST BACKEND_PORT FRONTEND_HOST FRONTEND_PORT VITE_PROXY_TARGET
}

# require_cmd：依赖缺失时给出「装什么、为什么需要」的可读说明
require_cmd() {
  local cmd="$1" hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "没有找到命令 $cmd。$hint"
  fi
}

check_tools() {
  require_cmd python3 "后端基于 Python 3.10+，请先安装 Python（并确保带 venv/virtualenv）。"
  require_cmd node "前端基于 Node.js 18+，请先安装 Node.js（随附 npm）。"
  require_cmd npm "前端依赖需要 npm（安装 Node.js 18+ 会自带；若单独安装请确认 npm 在 PATH 中）。"
}

# port_in_use <host> <port>：用标准库探测端口是否已被监听
port_in_use() {
  python3 - "$1" "$2" <<'PYEOF'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(0.5)
try:
    sys.exit(0 if sock.connect_ex((host, port)) == 0 else 1)
except OSError:
    sys.exit(1)
finally:
    sock.close()
PYEOF
}

# assert_port_free：端口被占用时说明是谁需要这个端口，而不是让服务静默换端口
assert_port_free() {
  local host="$1" port="$2" who="$3"
  local check_host="$host"
  [ "$check_host" = "0.0.0.0" ] && check_host="127.0.0.1"
  if port_in_use "$check_host" "$port"; then
    die "$who 需要监听 $host:$port，但该端口已被占用。
       可以停掉占用该端口的程序，或者修改 dev.config 里的端口后重新启动。
       查看占用进程（Linux）：lsof -iTCP:$port -sTCP:LISTEN"
  fi
}

# file_fingerprint <file...>：对依赖描述文件做指纹，指纹不变就跳过安装
file_fingerprint() {
  python3 - "$@" <<'PYEOF'
import hashlib, sys
digest = hashlib.sha256()
for path in sys.argv[1:]:
    digest.update(path.encode())
    with open(path, "rb") as fh:
        digest.update(fh.read())
print(digest.hexdigest())
PYEOF
}

# stamp_fresh <stamp文件> <期望指纹>
stamp_fresh() {
  [ -f "$1" ] && [ "$(cat "$1" 2>/dev/null)" = "$2" ]
}

# ensure_venv：后端虚拟环境不存在时创建，优先 venv，退回 virtualenv
ensure_venv() {
  local venv_python="$DEV_ROOT/backend/.venv/bin/python"
  if [ ! -x "$venv_python" ]; then
    log "首次运行：创建后端虚拟环境 backend/.venv"
    if ! python3 -m venv "$DEV_ROOT/backend/.venv" >/dev/null 2>&1; then
      if python3 -c "import virtualenv" >/dev/null 2>&1; then
        warn "当前 Python 缺少 venv 模块，改用已安装的 virtualenv 创建虚拟环境"
        python3 -m virtualenv -q "$DEV_ROOT/backend/.venv" \
          || die "virtualenv 创建虚拟环境失败，请检查 Python 安装后重试"
      else
        die "无法创建虚拟环境：当前 python3 缺少 venv 模块。
       Debian/Ubuntu 可执行：sudo apt-get install python3-venv
       或者先安装 virtualenv：python3 -m pip install --user virtualenv"
      fi
    fi
  fi
  [ -x "$venv_python" ] || die "backend/.venv 已损坏（缺少 bin/python），删除该目录后重新运行即可重建"
}

# install_backend_deps：按指纹决定是否安装；有锁文件时装锁定版本
install_backend_deps() {
  mkdir -p "$LOCK_STAMP_DIR"
  local lock="$DEV_ROOT/backend/requirements.lock"
  local req="$DEV_ROOT/backend/requirements.txt"
  local stamp="$LOCK_STAMP_DIR/backend.deps"
  local src="$lock"
  [ -f "$lock" ] || src="$req"
  local fp
  fp="$(file_fingerprint "$src")"
  if stamp_fresh "$stamp" "$fp" && [ -x "$DEV_ROOT/backend/.venv/bin/uvicorn" ]; then
    return 0
  fi

  ensure_venv
  if [ -f "$lock" ]; then
    log "安装后端依赖（按 requirements.lock 锁定版本）"
  else
    warn "未找到 backend/requirements.lock，退回 requirements.txt，跨机器版本可能不一致"
  fi
  if ! "$DEV_ROOT/backend/.venv/bin/pip" --disable-pip-version-check install -r "$src"; then
    die "后端依赖安装失败（pip install -r backend/$(basename "$src")）。
       常见原因：网络无法访问 PyPI、或锁文件里的版本不支持当前 Python。
       可检查网络/代理后重试；如需跳过锁定版本，可临时改用 requirements.txt 安装。"
  fi
  printf '%s' "$fp" > "$stamp"
}

# install_frontend_deps：优先 npm ci（严格按锁文件），无锁文件才退回 npm install
install_frontend_deps() {
  mkdir -p "$LOCK_STAMP_DIR"
  local lock="$DEV_ROOT/frontend/package-lock.json"
  local pkg="$DEV_ROOT/frontend/package.json"
  local stamp="$LOCK_STAMP_DIR/frontend.deps"
  local src="$lock"
  [ -f "$lock" ] || src="$pkg"
  local fp
  fp="$(file_fingerprint "$src")"
  if stamp_fresh "$stamp" "$fp" && [ -x "$DEV_ROOT/frontend/node_modules/.bin/vite" ]; then
    return 0
  fi

  if [ -f "$lock" ]; then
    log "安装前端依赖（npm ci，严格按 package-lock.json 锁定版本）"
    if ! (cd "$DEV_ROOT/frontend" && npm ci); then
      die "前端依赖安装失败（npm ci）。
       常见原因：网络无法访问 npm registry、或 node_modules 处于半安装状态。
       可删除 frontend/node_modules 后重试；registry 可用 npm config set registry 切换镜像。"
    fi
  else
    warn "未找到 frontend/package-lock.json，退回 npm install，跨机器版本可能不一致"
    if ! (cd "$DEV_ROOT/frontend" && npm install); then
      die "前端依赖安装失败（npm install），请检查网络或 npm registry 配置后重试"
    fi
  fi
  printf '%s' "$fp" > "$stamp"
}
