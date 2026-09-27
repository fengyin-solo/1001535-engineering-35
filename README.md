# 气象观测站网运维平台

面向区域气象观测站网的站点入网、传感器检定、观测数据质控、供电通信保障与运维结算的一体化运行监控后台。

这是一个前后端分离的管理平台：前端 Vue 3 + Vite + TypeScript，后端 FastAPI（Python）。
两边可以由仓库根目录的 `./dev.sh` 一条命令一起拉起，也保留各自独立启动的方式。
前端 dev server 已关掉自动打开页面，启动后按终端打印的地址手工打开。

## 目录结构

```text
.
├── dev.sh                    一条命令拉起前端 + 后端（含示例数据）
├── dev.config                本地端口与代理目标的唯一配置来源
├── scripts/
│   ├── install-deps.sh       只装依赖（前后端，按锁文件）
│   └── dev-common.sh         启动脚本共用的配置/安装/端口检查逻辑
├── frontend/                 Vue 3 + Vite + TypeScript 前端
│   ├── package-lock.json     前端依赖锁文件（npm ci 按它安装）
│   ├── src/views/            每个业务模块一个页面
│   ├── src/api/              统一请求封装
│   ├── src/stores/           会话与筛选状态
│   └── vite.config.ts        dev server 配置（open: false，strictPort）
├── backend/                  FastAPI（Python） 后端
│   ├── requirements.txt      后端依赖版本范围
│   ├── requirements.lock     后端依赖锁文件（本地/Docker 默认按它安装）
│   ├── run.sh                后端独立启动入口（README 手工方式仍可用）
│   ├── tests/                示例数据与接口模块一致性校验
│   ├── app/routers/          每个业务模块一组接口
│   ├── app/services/         业务规则与状态流转
│   └── app/seed.py           内存数据仓库的示例数据
├── Makefile
├── .gitignore
└── docker-compose.yml
```

## 环境要求

- Python 3.10+（需要带 `venv`；Debian/Ubuntu 若缺可 `sudo apt-get install python3-venv`）
- Node.js 18+（随附 npm）

## 一键启动（推荐）

```bash
# 第一次：安装两边依赖（按锁文件，换机器版本一致）
make install          # 等价于 ./scripts/install-deps.sh

# 之后每次：一条命令拉起后端（含示例数据）与前端
make dev              # 等价于 ./dev.sh
```

启动成功后日志会分别打印前端与后端的就绪状态：

```text
[ok]  后端已就绪：http://127.0.0.1:8000（健康检查通过，已载入 18 个业务模块的示例数据）
[ok]  前端已就绪：http://127.0.0.1:5173（页面中的 /api 请求会代理到 http://127.0.0.1:8000）
```

浏览器访问 `http://127.0.0.1:5173/`，按 `Ctrl-C` 会一并停止两个服务。

说明：

- 首次运行会创建 `backend/.venv` 并执行 `pip install -r requirements.lock`、
  在 `frontend/` 执行 `npm ci`。之后重复启动时，只要锁文件没变就直接跳过安装；
  想强制重装，删掉 `backend/.venv` 或 `frontend/node_modules` 即可。
- 依赖装不上、端口被占用、缺少 python3/node/npm 时会打印可读的中文说明，不会静默失败。

## 本地配置

端口与代理目标统一在仓库根目录的 `dev.config` 里维护（环境变量同名可临时覆盖）：

| 配置项 | 默认值 | 含义 |
| --- | --- | --- |
| `BACKEND_HOST` / `BACKEND_PORT` | `127.0.0.1` / `8000` | 后端 uvicorn 监听地址 |
| `FRONTEND_HOST` / `FRONTEND_PORT` | `127.0.0.1` / `5173` | 前端 vite dev server 监听地址 |
| `VITE_PROXY_TARGET` | 留空（自动推导） | 前端 `/api` 代理目标；留空时按后端地址端口自动拼接 |

改完端口重新执行 `./dev.sh` 即可，不需要再手工拼代理地址。

## 手工启动（仍然支持）

需要单独起一边、或调试某个服务时，可以沿用原来的方式：

### 后端

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
./run.sh
```

`run.sh` 同样会读根目录 `dev.config` 里的后端端口，并在依赖未变化时跳过安装。
健康检查：`curl http://127.0.0.1:8000/api/health`

### 前端

```bash
cd frontend
npm install
npm run dev
```

前端默认监听 `http://127.0.0.1:5173/`，dev server 不会自动打开浏览器，
需要自己访问。`/api` 由 vite 代理到后端 `http://127.0.0.1:8000`
（可用 `VITE_PROXY_TARGET` 环境变量覆盖）。

## 一致性校验

示例数据的模块数量必须与接口（路由）、运营概览保持一致：

```bash
make check        # 等价于 cd backend && .venv/bin/python -m unittest discover -s tests
```

新增或下线业务模块时，需要同时改 `app/routers/__init__.py`（注册路由）与
`app/seed.py`（示例数据），该校验会拦下两边对不上的情况。

## 业务模块

| 模块 | 目录 | 业务对象 | 主要字段 |
| --- | --- | --- | --- |
| 观测站点 | `station` | 观测站点 | 站点编码、站点名称、站点类别 |
| 观测传感器 | `sensor` | 观测传感器 | 传感器编号、所属站点、观测要素 |
| 观测记录 | `observation` | 观测记录 | 记录编号、所属站点、观测要素 |
| 数据质控 | `quality` | 质控任务 | 质控编号、质控时段、涉及站点 |
| 设备标定 | `calibration` | 标定记录 | 标定编号、标定对象、标定机构 |
| 数据传输 | `transmission` | 传输链路 | 链路编号、所属站点、传输方式 |
| 供电保障 | `power` | 供电单元 | 供电编号、所属站点、供电方式 |
| 站网布局 | `layout` | 站网规划 | 规划编号、规划区域、目标站距 |
| 巡检任务 | `inspection` | 巡检单 | 巡检单号、巡检站点、巡检人员 |
| 故障处置 | `fault` | 故障记录 | 故障编号、涉及站点、故障现象 |
| 备件器材 | `sparepart` | 备件器材 | 备件编号、备件名称、适用型号 |
| 元数据登记 | `metainfo` | 元数据记录 | 元数据编号、关联站点、元数据类型 |
| 告警监测 | `alarm` | 告警记录 | 告警编号、告警来源、告警类型 |
| 通信设备 | `comm` | 通信设备 | 设备编号、设备名称、设备型号 |
| 服务保障 | `service` | 服务事项 | 事项编号、服务对象、服务类别 |
| 运维合同 | `contract` | 运维合同 | 合同编号、服务单位、合同金额 |
| 经费结算 | `settlement` | 结算单 | 结算单号、关联合同、结算周期 |
| 人员培训 | `training` | 培训记录 | 培训编号、培训主题、培训对象 |

## 约定

- 每个模块的前端页面在 `frontend/src/views/<模块>/index.vue`，后端接口在
  `backend/app/routers/<模块>.py`，业务规则在 `backend/app/services/<模块>.py`。
- 列表接口统一返回 `{ items, total, page, size }`，动作接口统一返回 `{ ok, message }`。
- 状态流转只允许在 `app/services` 里改，路由层不做业务判断。
