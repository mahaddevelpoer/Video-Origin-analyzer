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
    model: "gemini-1.5-flash",
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
  try {
    return JSON.parse(text);
  } catch (_) {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]);
    } catch (_) {
      return null;
    }
  }
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
    const geminiKey = Deno.env.get("gm_key") || Deno.env.get("GM_KEY");

    if (!geminiKey || geminiKey.trim().length === 0) {
      return new Response(
        JSON.stringify(unavailableAi("MISSING_GEMINI_KEY", "Gemini API key is not configured in Supabase secrets.")),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const frameBase64List = (body.image_frames_base64 || [])
      .filter((frame) => typeof frame === "string" && frame.length > 0)
      .slice(0, 3);

    if (frameBase64List.length === 0) {
      return new Response(
        JSON.stringify(unavailableAi("NO_AI_FRAMES", "No frames were provided for Gemini visual review.")),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const prompt = `
You are the dedicated Gemini AI forensic review layer for a video origin analysis app.
Analyze the supplied video frame(s), OCR text, and candidate web matches.
Return ONLY valid JSON with exactly these fields:
{
  "summary": "one beginner-friendly sentence",
  "context_analysis": "Detailed professional narrative explaining the visual context (scene action, aspect ratio, fonts/UI styles, overlay text) and how this relates to the likely platform.",
  "likely_platform": "instagram|tiktok|youtube|facebook|other|unknown",
  "confidence": 0-100,
  "evidence_reasons": ["short concrete reason"],
  "conflicts": ["short conflict or uncertainty"],
  "recommended_search_queries": ["query user/app could try"],
  "source_urls": ["urls you relied on from candidate matches or search grounding"],
  "risk_level": "low|medium|high|unknown"
}
Rules:
- Do not claim original authorship. Only discuss public evidence and likely platform origin.
- Prefer direct platform URLs, exact visual matches, OCR handles, captions, and timestamps.
- Write context_analysis like a professional forensic report summary.
OCR text/query: ${body.ocr_query || "none"}
Candidate matches: ${JSON.stringify(body.candidate_matches || [])}
`;

    const parts: any[] = [{ text: prompt }];
    for (const frame of frameBase64List) {
      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: cleanBase64Image(frame),
        },
      });
    }

    const candidateModels = [
      "gemini-2.5-flash",
      "gemini-flash-latest",
      "gemini-3.5-flash",
      "gemini-3.6-flash",
      "gemini-2.5-pro",
    ];
    let lastError = "";

    for (const modelName of candidateModels) {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(geminiKey)}`;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 12000);

      try {
        let response = await fetch(endpoint, {
          method: "POST",
          signal: controller.signal,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts }],
            tools: [{ googleSearch: {} }],
            generationConfig: {
              temperature: 0.15,
              maxOutputTokens: 900,
              responseMimeType: "application/json",
            },
          }),
        });

        // Retry without tools if first attempt failed
        if (!response.ok) {
          response = await fetch(endpoint, {
            method: "POST",
            signal: controller.signal,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ role: "user", parts }],
              generationConfig: {
                temperature: 0.15,
                maxOutputTokens: 900,
                responseMimeType: "application/json",
              },
            }),
          });
        }

        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          lastError = `${response.status} (${modelName}): ${errText.slice(0, 150)}`;
          continue;
        }

        const json = await response.json();
        const text =
          json?.candidates?.[0]?.content?.parts
            ?.map((part: any) => part.text || "")
            .join("\n")
            .trim() || "";
        const parsed = extractJsonObject(text);

        if (!parsed) {
          lastError = `Invalid JSON response from ${modelName}`;
          continue;
        }

        const sourceUrls = normalizeStringList(parsed.source_urls);
        const groundingUrls =
          json?.candidates?.[0]?.groundingMetadata?.groundingChunks
            ?.map((chunk: any) => chunk?.web?.uri)
            ?.filter((uri: unknown) => typeof uri === "string") || [];

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
          source_urls: Array.from(new Set([...sourceUrls, ...groundingUrls])).slice(0, 8),
          risk_level: normalizeRisk(parsed.risk_level),
        };

        return new Response(JSON.stringify(result), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } catch (err: any) {
        lastError = err?.name === "AbortError" ? `Timeout (${modelName})` : `Error (${modelName})`;
      } finally {
        clearTimeout(timeout);
      }
    }

    return new Response(
      JSON.stringify(unavailableAi("GEMINI_FAILED", `Gemini review unavailable: ${lastError}`)),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify(unavailableAi("EXCEPTION", `Internal edge function error: ${err?.message}`)),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
