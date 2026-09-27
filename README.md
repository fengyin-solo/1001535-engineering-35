# 气象观测站网运维平台

面向区域气象观测站网的站点入网、传感器检定、观测数据质控、供电通信保障与运维结算的一体化运行监控后台。

这是一个前后端分离的管理平台：前端 Vue 3 + Vite + TypeScript，后端 FastAPI（Python）。
两边各自独立启动，前端 dev server 已关掉自动打开页面，启动后按终端打印的地址手工打开。

## 目录结构

```text
.
├── frontend/                 Vue 3 + Vite + TypeScript 前端
│   ├── src/views/            每个业务模块一个页面
│   ├── src/api/              统一请求封装
│   ├── src/stores/           会话与筛选状态
│   └── vite.config.ts        dev server 配置（open: false）
├── backend/                  FastAPI（Python） 后端
│   ├── app/routers/          每个业务模块一组接口
│   ├── app/services/         业务规则与状态流转
│   └── app/store.py          内存数据仓库与示例数据
├── scripts/dev.sh            一键启动前后端（含示例数据）
├── .env.example              端口等本地配置模板，复制为 .env 后生效
├── .gitignore
└── docker-compose.yml
```

## 一键启动（推荐）

```bash
make dev          # 等价于 ./scripts/dev.sh
```

首次运行会自动建虚拟环境、装前后端依赖并载入示例数据；之后重复启动会跳过
已装好的依赖，直接起服务。端口、代理目标等配置统一从根目录 `.env` 读
（首次运行会按 `.env.example` 自动生成，改端口只改这一处）。

启动日志里会分别看到 `[backend]` / `[frontend]` 的就绪行；依赖装不上、
端口被占用时会打印可读的原因和处理建议。`Ctrl+C` 可同时停止前后端。

依赖版本已锁定（后端 `backend/requirements.txt` 全部钉版，前端
`package-lock.json` 已入库），换台机器装出来的版本一致。

## 手工启动

### 后端

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
./run.sh
```

`run.sh` 幂等：`.venv` 已存在且依赖没变时会跳过安装直接启动；
端口取自根目录 `.env` 的 `BACKEND_PORT`（默认 8000）。

健康检查：`curl http://127.0.0.1:8000/api/health`

### 前端

```bash
cd frontend
npm install
npm run dev
```

前端默认监听 `http://127.0.0.1:5173/`，dev server 不会自动打开浏览器，
需要自己访问。`/api` 由 vite 代理到后端，目标地址从根目录 `.env` 的
`BACKEND_HOST`/`BACKEND_PORT` 读（默认 `http://127.0.0.1:8000`），
也可用环境变量 `VITE_PROXY_TARGET` 临时覆盖。

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
