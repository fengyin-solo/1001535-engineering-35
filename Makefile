.PHONY: install dev backend frontend check

# 安装两边依赖（按锁文件；依赖未变化时跳过）
install:
	./scripts/install-deps.sh

# 一条命令拉起后端（含示例数据）与前端，Ctrl-C 一并停止
dev:
	./dev.sh

# 既有手工启动方式仍然保留，可单独起一边
backend:
	cd backend && ./run.sh

frontend:
	cd frontend && npm run dev

# 校验示例数据模块数与接口（路由）数一致
check:
	cd backend && .venv/bin/python -m unittest discover -s tests -v
