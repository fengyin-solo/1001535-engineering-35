FROM python:3.12-slim
WORKDIR /srv/app
# 优先按锁文件安装，保证镜像与本地版本一致
COPY requirements.lock requirements.txt ./
RUN pip install --no-cache-dir -r requirements.lock
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
