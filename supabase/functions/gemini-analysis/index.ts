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
  endpointUrl: string,
  apiKey: string,
  parts: unknown[],
  useJsonMode: boolean,
  signal: AbortSignal,
): Promise<Response> {
  const generationConfig: Record<string, unknown> = {
    temperature: 0.1,
    maxOutputTokens: 1024,
  };

  if (useJsonMode) {
    generationConfig["responseMimeType"] = "application/json";
  }

  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts }],
    generationConfig,
  };

  return await fetch(endpointUrl, {
    method: "POST",
    signal,
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
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

    // Debug: fetch available models if key fails
    const listModelsRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(geminiKey)}`).catch(() => null);
    const listModelsJson = listModelsRes ? await listModelsRes.json().catch(() => null) : null;
    const availableModelNames = (listModelsJson?.models || []).map((m: any) => m.name);
    console.log("Available Gemini Models for Key:", availableModelNames);

    const frameBase64List = (body.image_frames_base64 || [])
      .filter((frame) => typeof frame === "string" && frame.length > 10)
      .slice(0, 2); // Max 2 frames to reduce payload size & latency

    if (frameBase64List.length === 0) {
      return new Response(
        JSON.stringify(unavailableAi("NO_AI_FRAMES", "No frames were provided for Gemini visual review.")),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const candidateMatchesText = (body.candidate_matches || [])
      .slice(0, 8)
      .map((m, i) => `[${i + 1}] Platform: ${m.platform} | Title: "${m.title}" | Link: ${m.link}${m.snippet ? ` | Snippet: "${m.snippet}"` : ""}`)
      .join("\n");

    const prompt = `You are an expert forensic video origin analyst. Analyze the video frame(s), extracted OCR text, and candidate web matches.

INSTRUCTIONS:
1. Examine visual UI elements: aspect ratio (vertical 9:16 vs horizontal 16:9), watermarks (TikTok bouncing logo, Instagram Reels camera icon/handle, YouTube Shorts icon), font styles, audio stickers, like/comment button layouts, and caption positions.
2. Cross-reference the candidate web search matches below with the image content and OCR text to determine if the video originated from Instagram, TikTok, YouTube, Facebook, or elsewhere.
3. If candidate web matches match the video content or OCR handles/titles, use them to confirm platform, calculate high confidence (70-95%), and cite source URLs.
4. If candidate matches conflict or show zero matches, analyze pure visual cues and state reasons clearly.

Candidate Web Search Matches:
${candidateMatchesText || "None (Visual analysis only)"}

Extracted OCR Text / Handles:
${body.ocr_query || "None"}

Return ONLY a valid JSON object (no markdown formatting, no text outside JSON) with these fields:
{
  "summary": "Clear, concise 1-sentence conclusion about the video origin and content.",
  "context_analysis": "Detailed forensic breakdown analyzing scene visual features, UI overlay elements, OCR text/handles, and web search evidence.",
  "likely_platform": "instagram|tiktok|youtube|facebook|other|unknown",
  "confidence": 0 to 100,
  "evidence_reasons": ["Specific evidence point 1", "Specific evidence point 2"],
  "conflicts": ["Any conflicting visual or web evidence point"],
  "recommended_search_queries": ["Suggested search query to locate original video"],
  "source_urls": ["URL from candidate matches that confirms origin"],
  "risk_level": "low|medium|high|unknown"
}`;

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
    const modelEndpoints = [
      { name: "gemini-2.5-flash", url: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${encodeURIComponent(geminiKey)}` },
      { name: "gemini-2.5-flash-lite", url: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${encodeURIComponent(geminiKey)}` },
      { name: "gemini-3.5-flash-lite", url: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${encodeURIComponent(geminiKey)}` },
      { name: "gemini-3.5-flash", url: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${encodeURIComponent(geminiKey)}` },
    ];

    let lastError = "";

    for (const target of modelEndpoints) {
      const modelName = target.name;
      const endpoint = target.url;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 20000);

      try {
        let response = await callGemini(endpoint, geminiKey, parts, true, controller.signal);

        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          console.log(`${modelName} JSON mode failed (${response.status}): ${errText.slice(0, 100)}`);
          await new Promise((r) => setTimeout(r, 300));
          response = await callGemini(endpoint, geminiKey, parts, false, controller.signal);
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
