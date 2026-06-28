// 内容审核：配了 DEEPSEEK_API_KEY 走真审核；否则走本地兜底（关键词+默认放行）。
// 服务器在国内云，DeepSeek 直连顺。

export type ModerationResult = { approved: boolean; reason: string };

const BLOCKLIST = ["法轮功", "习近平", "颠覆国家", "儿童色情", "制造炸弹", "枪支买卖"];

function localFallback(text: string): ModerationResult {
  const hit = BLOCKLIST.find((w) => text.includes(w));
  return hit
    ? { approved: false, reason: `命中敏感词「${hit}」（本地兜底审核）` }
    : { approved: true, reason: "本地兜底审核通过" };
}

export async function moderate(title: string, body: string): Promise<ModerationResult> {
  const key = process.env.DEEPSEEK_API_KEY;
  const text = `${title}\n${body}`.slice(0, 6000); // 截断，控成本
  if (!key) return localFallback(text);

  try {
    const resp = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model: "deepseek-chat",
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "你是中文小说平台的内容审核员。判断给定文本是否违反中国大陆法律法规或平台规范" +
              "（涉政敏感、暴恐、色情低俗、未成年人不良信息、违法犯罪教程等）。" +
              '只输出 JSON：{"approved": true/false, "reason": "简短中文理由"}。' +
              "正常的言情/悬疑/犯罪推理等虚构情节应当通过。",
          },
          { role: "user", content: text },
        ],
      }),
    });
    if (!resp.ok) {
      console.warn("DeepSeek 审核 HTTP", resp.status, "→ 本地兜底");
      return localFallback(text);
    }
    const data: any = await resp.json();
    const raw = data?.choices?.[0]?.message?.content ?? "{}";
    const parsed = JSON.parse(raw);
    return {
      approved: Boolean(parsed.approved),
      reason: String(parsed.reason ?? "").slice(0, 200) || "DeepSeek 审核",
    };
  } catch (e) {
    console.warn("DeepSeek 审核异常 → 本地兜底:", e);
    return localFallback(text);
  }
}
