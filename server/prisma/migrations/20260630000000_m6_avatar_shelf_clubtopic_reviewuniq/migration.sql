-- M6: 头像URL / 书架状态 / 俱乐部话题 / 书评唯一
ALTER TABLE "User" ADD COLUMN "avatarUrl" TEXT;
ALTER TABLE "Favorite" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'want';
ALTER TABLE "Topic" ADD COLUMN "clubId" TEXT;

-- 书评：同一用户同一本书唯一（迁移前已去重）
CREATE UNIQUE INDEX "Review_userId_bookId_key" ON "Review"("userId", "bookId");
