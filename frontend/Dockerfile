FROM node:20-alpine
WORKDIR /srv/web
# npm ci 严格按 package-lock.json 安装，镜像里不会出现版本漂移
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
