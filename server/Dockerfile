# XuMo API 镜像。原型阶段直接用 tsx 跑 TS，省构建步骤。
FROM node:20-alpine

WORKDIR /app

# 先装依赖（利用缓存）
COPY package.json ./
RUN npm install

# Prisma schema 先拷进来生成 client
COPY prisma ./prisma
RUN npx prisma generate

# 业务代码
COPY tsconfig.json ./
COPY src ./src

EXPOSE 3000
CMD ["npx", "tsx", "src/index.ts"]
