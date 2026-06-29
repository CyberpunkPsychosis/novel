-- M7: 俱乐部建者 / 通知跳转目标 / 运营精选
ALTER TABLE "Club" ADD COLUMN "ownerId" TEXT;
ALTER TABLE "Notification" ADD COLUMN "targetKind" TEXT;
ALTER TABLE "Notification" ADD COLUMN "targetId" TEXT;
ALTER TABLE "Book" ADD COLUMN "featured" BOOLEAN NOT NULL DEFAULT false;
