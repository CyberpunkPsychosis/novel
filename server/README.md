# XuMo 后端 · 里程碑 1

账号（Sign in with Apple）+ 书/章节云端存取 + 阅读进度跨设备同步。
Fastify + Prisma + PostgreSQL + JWT，Docker Compose 一键起。

## 本地快速起（Docker）
```bash
cd server
cp .env.example .env            # 按需改 JWT_SECRET / APPLE_BUNDLE_ID
docker compose up -d            # 起 postgres + api
docker compose exec api npx prisma migrate deploy   # 建表
npm install                     # 本机装一份依赖给 seed 用
npm run db:seed                 # 从 ../ios-app/.../seed.json 灌 4 本书 101 章
curl localhost:3000/books | head -c 300
```
> seed 从宿主机跑（要读仓库里的 seed.json）；postgres 端口已映射到 localhost:5432，
> seed 用 `.env` 里的 `DATABASE_URL`（localhost）即可。

## 不用 Docker 跑 API（开发热重载）
```bash
cd server
npm install
# 需有一个 postgres：docker compose up -d db
cp .env.example .env
npx prisma migrate dev --name init
npm run db:seed
npm run dev                     # tsx watch，改代码热重载
```

## 接口（里程碑 1）
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/auth/apple` | 否 | `{identityToken, penName?}` → `{token, user}` |
| POST | `/auth/dev` | 否 | 开发期邮箱通道 `{email, penName?}`（`DEV_EMAIL_LOGIN=true` 时开）|
| GET | `/me` | JWT | 当前用户 |
| GET | `/books` | 否 | 全部书（含章节）|
| GET | `/books/:id` | 否 | 单本书 |
| POST | `/books` | JWT | 上传原创新作 |
| GET | `/me/progress` | JWT | `{bookId: chapterIndex}` |
| PUT | `/me/progress` | JWT | `{bookId, chapterIndex}` |

## 部署到国内云（阿里云 ECS / 腾讯云 CVM）
1. 装 Docker，`git clone` 后 `cd server`，配 `.env`（`JWT_SECRET` 用 `openssl rand -hex 32`）。
2. `docker compose up -d` → `docker compose exec api npx prisma migrate deploy`。
3. 灌种子：在能读到 `ios-app/.../seed.json` 的机器上 `npm run db:seed`，
   或把 seed.json 拷进容器并设 `SEED_FILE` 后 `docker compose exec api npm run db:seed`。
4. Nginx 反代 `api.<域名>` → `127.0.0.1:3000`，certbot 上 HTTPS。
   **生产域名走 80/443 前需完成 ICP 备案**；备案期可先用 ECS 公网 IP:3000 直连（iOS 加 ATS 例外）。

## 上线前务必
- `DEV_EMAIL_LOGIN=false`（关掉无校验的邮箱通道）
- `JWT_SECRET` 换成随机长串
- `APPLE_BUNDLE_ID` 设为真实 App bundle id
