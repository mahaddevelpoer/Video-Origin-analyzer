// Supabase Edge Function: gemini-analysis
// Dedicated Gemini AI Multimodal Vision & Forensic Context Analyzer
// Developer: Mahad and Mehdi Developers - Video Origin Analyzer

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

type Platform = "instagram" | "tiktok" | "youtube" | "facebook" | "other" | "unknown";

interface RequestPayload {
  image_frames_base64?: string[];
  ocr_query?: string;
  candidate_matches?: Array<{
    title: string;
    link: string;
    platform: string;
    snippet?: string;
  }>;
}

interface AiAnalysisResponse {
  status: "success" | "unavailable";
  model: string;
  summary: string;
  context_analysis: string;
  likely_platform: Platform;
  confidence: number;
  evidence_reasons: string[];
  conflicts: string[];
  recommended_search_queries: string[];
  source_urls: string[];
  risk_level: "low" | "medium" | "high" | "unknown";
  error_code?: string;
}

function cleanBase64Image(raw: string): string {
  return raw.replace(/^data:image\/\w+;base64,/, "");
}

function unavailableAi(errorCode: string, message: string): AiAnalysisResponse {
  return {
    status: "unavailable",
    model: "none",
    summary: message,
    context_analysis: "Visual context analysis is unavailable.",
    likely_platform: "unknown",
    confidence: 0,
    evidence_reasons: [],
    conflicts: [],
    recommended_search_queries: [],
    source_urls: [],
    risk_level: "unknown",
    error_code: errorCode,
  };
}

function clampConfidence(value: unknown): number {
  if (typeof value !== "number" || Number.isNaN(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function normalizeStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => typeof item === "string" && item.trim().length > 0)
    .map((item) => item.trim())
    .slice(0, 8);
}

function normalizePlatform(value: unknown): Platform {
  if (typeof value !== "string") return "unknown";
  const lower = value.toLowerCase();
  if (
    lower === "instagram" ||
    lower === "tiktok" ||
    lower === "youtube" ||
    lower === "facebook" ||
    lower === "other"
  ) {
    return lower;
  }
  return "unknown";
}

function normalizeRisk(value: unknown): "low" | "medium" | "high" | "unknown" {
  if (typeof value !== "string") return "unknown";
  const lower = value.toLowerCase();
  if (lower === "low" || lower === "medium" || lower === "high") return lower;
  return "unknown";
}

function extractJsonObject(text: string): Record<string, unknown> | null {
  // Try direct parse
  try {
    const parsed = JSON.parse(text);
    if (typeof parsed === "object" && parsed !== null) return parsed;
  } catch (_) { /* fall through */ }

  // Extract from markdown code block ```json ... ```
  const codeBlockMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) {
    try {
      const parsed = JSON.parse(codeBlockMatch[1].trim());
      if (typeof parsed === "object" && parsed !== null) return parsed;
    } catch (_) { /* fall through */ }
  }

  // Extract bare {...} object
  const match = text.match(/\{[\s\S]*\}/);
  if (match) {
    try {
      const parsed = JSON.parse(match[0]);
      if (typeof parsed === "object" && parsed !== null) return parsed;
    } catch (_) { /* fall through */ }
  }

  return null;
}

async function callGemini(
  endpoint: string,
  parts: unknown[],
  useJsonMode: boolean,
  signal: AbortSignal,
): Promise<Response> {
  const generationConfig: Record<string, unknown> = {
    temperature: 0.1,
    maxOutputTokens: 1024,
  };

  // Only set responseMimeType when NOT using googleSearch tool
  // (they are mutually exclusive on some models)
  if (useJsonMode) {
    generationConfig["responseMimeType"] = "application/json";
  }

  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts }],
    generationConfig,
  };

  // Do NOT include tools - they cause timeouts on free tier
  // and responseMimeType conflict

  return await fetch(endpoint, {
    method: "POST",
    signal,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: RequestPayload = await req.json().catch(() => ({}));
    const geminiKey = Deno.env.get("gm_key") || Deno.env.get("GM_KEY") || Deno.env.get("GEMINI_API_KEY");

    if (!geminiKey || geminiKey.trim().length === 0) {
      return new Response(
        JSON.stringify(unavailableAi("MISSING_GEMINI_KEY", "Gemini API key is not configured in Supabase secrets.")),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const frameBase64List = (body.image_frames_base64 || [])
      .filter((frame) => typeof frame === "string" && frame.length > 10)
      .slice(0, 2); // Max 2 frames to reduce payload size & latency

    if (frameBase64List.length === 0) {
      return new Response(
        JSON.stringify(unavailableAi("NO_AI_FRAMES", "No frames were provided for Gemini visual review.")),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const prompt = `You are a forensic video analyst. Analyze the video frame(s) and any OCR/web context provided.
Return ONLY a valid JSON object with exactly these fields (no markdown, no extra text):
{
  "summary": "One clear sentence about what this content is.",
  "context_analysis": "Professional forensic description of the visual content, UI elements, aspect ratio, text overlays, and what platform this looks like.",
  "likely_platform": "instagram or tiktok or youtube or facebook or other or unknown",
  "confidence": 0-100,
  "evidence_reasons": ["reason 1", "reason 2"],
  "conflicts": ["any conflicting signal"],
  "recommended_search_queries": ["search query"],
  "source_urls": [],
  "risk_level": "low or medium or high or unknown"
}
OCR text: ${body.ocr_query || "none"}
Candidate web matches: ${JSON.stringify((body.candidate_matches || []).slice(0, 5))}`;

    const parts: unknown[] = [{ text: prompt }];
    for (const frame of frameBase64List) {
      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: cleanBase64Image(frame),
        },
      });
    }

    // Free-tier models that work with v1beta - ordered by speed
    // gemini-2.5-flash is the primary free model
    const candidateModels = [
      "gemini-2.5-flash",
      "gemini-2.0-flash",
      "gemini-2.0-flash-lite",
    ];

    let lastError = "";

    for (const modelName of candidateModels) {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(geminiKey)}`;
      const controller = new AbortController();
      // 28s timeout - enough for free tier, leaves margin under Supabase 60s limit
      const timeout = setTimeout(() => controller.abort(), 28000);

      try {
        // First try: with JSON mode
        let response = await callGemini(endpoint, parts, true, controller.signal);

        // If JSON mode fails, retry without it (text mode)
        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          console.log(`${modelName} JSON mode failed (${response.status}): ${errText.slice(0, 100)}`);
          // Small delay before retry
          await new Promise((r) => setTimeout(r, 500));
          response = await callGemini(endpoint, parts, false, controller.signal);
        }

        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          lastError = `${response.status} (${modelName}): ${errText.slice(0, 200)}`;
          console.log(`${modelName} failed: ${lastError}`);
          continue;
        }

        const json = await response.json();
        const rawText =
          json?.candidates?.[0]?.content?.parts
            ?.map((part: { text?: string }) => part.text || "")
            .join("\n")
            .trim() || "";

        console.log(`${modelName} raw response (${rawText.length} chars): ${rawText.slice(0, 200)}`);

        const parsed = extractJsonObject(rawText);

        if (!parsed) {
          lastError = `${modelName}: Could not parse JSON from response: "${rawText.slice(0, 100)}"`;
          continue;
        }

        const result: AiAnalysisResponse = {
          status: "success",
          model: modelName,
          summary:
            typeof parsed.summary === "string" && parsed.summary.trim().length > 0
              ? parsed.summary.trim()
              : "AI reviewed the visual and web evidence.",
          context_analysis:
            typeof parsed.context_analysis === "string" && parsed.context_analysis.trim().length > 0
              ? parsed.context_analysis.trim()
              : "Context analysis not provided.",
          likely_platform: normalizePlatform(parsed.likely_platform),
          confidence: clampConfidence(parsed.confidence),
          evidence_reasons: normalizeStringList(parsed.evidence_reasons),
          conflicts: normalizeStringList(parsed.conflicts),
          recommended_search_queries: normalizeStringList(parsed.recommended_search_queries),
          source_urls: normalizeStringList(parsed.source_urls),
          risk_level: normalizeRisk(parsed.risk_level),
        };

        clearTimeout(timeout);
        return new Response(JSON.stringify(result), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } catch (err: unknown) {
        const errAny = err as { name?: string; message?: string };
        if (errAny?.name === "AbortError") {
          lastError = `TIMEOUT on ${modelName} after 28s`;
          console.log(lastError);
        } else {
          lastError = `Exception on ${modelName}: ${errAny?.message}`;
          console.log(lastError);
        }
      } finally {
        clearTimeout(timeout);
      }
    }

    // All models failed
    return new Response(
      JSON.stringify(unavailableAi("GEMINI_FAILED", `Gemini review unavailable: ${lastError}`)),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: unknown) {
    const errAny = err as { message?: string };
    return new Response(
      JSON.stringify(unavailableAi("EXCEPTION", `Internal edge function error: ${errAny?.message}`)),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
