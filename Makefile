.PHONY: install dev backend frontend

install:
	cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
	cd frontend && npm install

# 一条命令拉起前端 + 后端（含示例数据），依赖已装时会自动跳过安装
dev:
	./scripts/dev.sh

backend:
	cd backend && ./run.sh

frontend:
	cd frontend && npm run dev
