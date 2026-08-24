// Supabase Edge Function: visual-search
// Hybrid proxy: SerpApi Google Lens exact/related matches + Gemini AI evidence review
// Developer: Mahad and Mehdi Developers - Video Origin Analyzer

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const GEMINI_MODEL = "gemini-2.0-flash";
const GEMINI_ENDPOINT =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

type Platform = "instagram" | "tiktok" | "youtube" | "facebook" | "other";

interface RequestPayload {
  image_base64?: string;
  image_frames_base64?: string[];
  image_url?: string;
  max_results?: number;
  ocr_query?: string;
}

interface VisualMatch {
  position: number;
  title: string;
  link: string;
  domain: string;
  classified_platform: Platform;
  thumbnail?: string;
  source?: string;
  match_type?: "exact_match" | "visual_match" | "ocr_search";
  date?: string;
  snippet?: string;
}

interface AiAnalysis {
  status: "success" | "unavailable";
  model: string;
  summary: string;
  context_analysis: string;
  likely_platform: Platform | "unknown";
  confidence: number;
  evidence_reasons: string[];
  conflicts: string[];
  recommended_search_queries: string[];
  source_urls: string[];
  risk_level: "low" | "medium" | "high" | "unknown";
  error_code?: string;
}

function classifyDomain(urlString: string): Platform {
  try {
    const host = new URL(urlString).hostname.toLowerCase();
    if (host === "instagram.com" || host.endsWith(".instagram.com")) {
      return "instagram";
    }
    if (host === "tiktok.com" || host.endsWith(".tiktok.com")) {
      return "tiktok";
    }
    if (
      host === "youtube.com" ||
      host.endsWith(".youtube.com") ||
      host === "youtu.be" ||
      host.endsWith(".youtu.be")
    ) {
      return "youtube";
    }
    if (
      host === "facebook.com" ||
      host.endsWith(".facebook.com") ||
      host === "fb.com" ||
      host === "fb.watch" ||
      host.endsWith(".fb.com")
    ) {
      return "facebook";
    }
    return "other";
  } catch (_) {
    return "other";
  }
}

function extractDomain(urlString: string): string {
  try {
    return new URL(urlString).hostname.toLowerCase();
  } catch (_) {
    return "unknown";
  }
}

function cleanBase64Image(raw: string): string {
  return raw.replace(/^data:image\/\w+;base64,/, "");
}

function unavailableAi(errorCode: string, message: string): AiAnalysis {
  return {
    status: "unavailable",
    model: GEMINI_MODEL,
    summary: message,
    context_analysis: "Visual context analysis is unavailable because the AI service could not be reached.",
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

function normalizePlatform(value: unknown): Platform | "unknown" {
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

async function fetchSerpApiMatches(
  serpApiKey: string,
  imageBase64: string | undefined,
  imageUrl: string | undefined,
  maxResults: number,
): Promise<{ matches: VisualMatch[]; error?: { message: string; code: string } }> {
  let queryUrl = "";

  if (imageBase64) {
    const cleanBase64 = cleanBase64Image(imageBase64);
    const binaryData = Uint8Array.from(atob(cleanBase64), (c) => c.charCodeAt(0));

    if (binaryData.length > 500 * 1024) {
      return {
        matches: [],
        error: {
          message: "Image frame size exceeds 500KB limit for visual search.",
          code: "FRAME_TOO_LARGE",
        },
      };
    }

    const formData = new FormData();
    formData.append("image", new Blob([binaryData], { type: "image/jpeg" }), "frame.jpg");
    formData.append("api_key", serpApiKey);

    const uploadRes = await fetch("https://serpapi.com/image", {
      method: "POST",
      body: formData,
    });

    if (!uploadRes.ok) {
      return {
        matches: [],
        error: {
          message: `SerpApi image upload failed: ${uploadRes.status}`,
          code: "SERPAPI_UPLOAD_FAILED",
        },
      };
    }

    const uploadJson = await uploadRes.json();
    const searchImageId = uploadJson.image_id;
    if (!searchImageId) {
      return {
        matches: [],
        error: {
          message: "SerpApi did not return an image_id.",
          code: "SERPAPI_NO_IMAGE_ID",
        },
      };
    }

    queryUrl =
      `https://serpapi.com/search.json?engine=google_lens&image_id=${encodeURIComponent(
        searchImageId,
      )}&api_key=${encodeURIComponent(serpApiKey)}`;
  } else if (imageUrl) {
    queryUrl =
      `https://serpapi.com/search.json?engine=google_lens&url=${encodeURIComponent(
        imageUrl,
      )}&api_key=${encodeURIComponent(serpApiKey)}`;
  } else {
    return {
      matches: [],
      error: { message: "No image supplied for SerpApi search.", code: "BAD_INPUT" },
    };
  }

  const lensRes = await fetch(queryUrl);
  if (!lensRes.ok) {
    return {
      matches: [],
      error: {
        message: `SerpApi Google Lens search failed with status ${lensRes.status}`,
        code: "SERPAPI_SEARCH_FAILED",
      },
    };
  }

  const lensData = await lensRes.json();
  const exactMatches = lensData.exact_matches || lensData.exact_match || [];
  const rawMatches = [
    ...exactMatches.map((item: any) => ({ ...item, __matchType: "exact_match" })),
    ...(lensData.visual_matches || []).map((item: any) => ({
      ...item,
      __matchType: "visual_match",
    })),
  ];

  const matches: VisualMatch[] = [];
  for (const item of rawMatches) {
    if (matches.length >= maxResults) break;
    const link = item.link || "";
    if (!link) continue;
    matches.push({
      position: matches.length + 1,
      title: item.title || "Related Visual Result",
      link,
      domain: extractDomain(link),
      classified_platform: classifyDomain(link),
      thumbnail: item.thumbnail || item.source_icon,
      source: item.source,
      match_type: item.__matchType,
      date: item.date || item.snippet_date,
      snippet: item.snippet,
    });
  }

  return { matches };
}

async function fetchOcrMatches(
  serpApiKey: string,
  ocrQuery: string | undefined,
  maxResults: number,
  existingLinks: Set<string>,
): Promise<VisualMatch[]> {
  if (!ocrQuery || ocrQuery.trim().length < 2 || maxResults <= 0) return [];
  const query =
    `${ocrQuery.trim()} video (site:tiktok.com OR site:instagram.com OR site:youtube.com)`;
  const ocrUrl =
    `https://serpapi.com/search.json?engine=google&q=${encodeURIComponent(query)}&num=${Math.min(
      10,
      maxResults,
    )}&api_key=${encodeURIComponent(serpApiKey)}`;

  const ocrResponse = await fetch(ocrUrl);
  if (!ocrResponse.ok) return [];
  const ocrData = await ocrResponse.json();
  const matches: VisualMatch[] = [];

  for (const item of ocrData.organic_results || []) {
    if (matches.length >= maxResults) break;
    const link = item.link || "";
    if (!link || existingLinks.has(link)) continue;
    existingLinks.add(link);
    matches.push({
      position: matches.length + 1,
      title: item.title || "OCR-related video result",
      link,
      domain: extractDomain(link),
      classified_platform: classifyDomain(link),
      thumbnail: item.thumbnail,
      source: item.source || "OCR web search",
      match_type: "ocr_search",
      date: item.date,
      snippet: item.snippet,
    });
  }

  return matches;
}

async function fetchGeminiAnalysis(
  geminiKey: string | undefined,
  frameBase64List: string[],
  ocrQuery: string | undefined,
  matches: VisualMatch[],
): Promise<AiAnalysis> {
  if (!geminiKey || geminiKey.trim().length === 0) {
    return unavailableAi("MISSING_GEMINI_KEY", "Gemini AI key is not configured.");
  }
  if (frameBase64List.length === 0) {
    return unavailableAi("NO_AI_FRAMES", "No frames were available for Gemini review.");
  }

  const candidateMatches = matches.slice(0, 12).map((match) => ({
    title: match.title,
    link: match.link,
    platform: match.classified_platform,
    match_type: match.match_type,
    date: match.date,
    snippet: match.snippet,
  }));

  const prompt = `
You are the AI evidence-review layer for a video origin forensic app.
Analyze the supplied video frame(s), OCR text, and candidate web matches.
Return ONLY valid JSON with exactly these fields:
{
  "summary": "one beginner-friendly sentence",
  "context_analysis": "Detailed professional narrative explaining the visual context (what is happening, aspect ratio, fonts/UI styles, overlay text) and how this relates to the likely platform.",
  "likely_platform": "instagram|tiktok|youtube|facebook|other|unknown",
  "confidence": 0-100,
  "evidence_reasons": ["short concrete reason"],
  "conflicts": ["short conflict or uncertainty"],
  "recommended_search_queries": ["query user/app could try"],
  "source_urls": ["urls you relied on from candidate matches or search grounding"],
  "risk_level": "low|medium|high|unknown"
}
Rules:
- Do not claim original authorship. Only discuss earliest public evidence and likely platform.
- Prefer direct platform URLs, exact visual matches, OCR handles, captions, timestamps, and cited source URLs.
- If evidence is weak, set likely_platform to "unknown" or confidence below 45.
- If candidate matches conflict, describe the conflict instead of forcing certainty.
- The context_analysis should be written like a professional forensic report summary.
- Keep arrays concise.
OCR text/query: ${ocrQuery || "none"}
Candidate matches JSON: ${JSON.stringify(candidateMatches)}
`;

  const parts: any[] = [{ text: prompt }];
  for (const frame of frameBase64List.slice(0, 3)) {
    parts.push({
      inline_data: {
        mime_type: "image/jpeg",
        data: cleanBase64Image(frame),
      },
    });
  }

  const candidateModels = ["gemini-1.5-flash", "gemini-2.0-flash", "gemini-1.5-pro"];
  let lastErrorStatus = "";

  for (const modelName of candidateModels) {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);

    try {
      // First attempt with grounding search tool (using correct camelCase googleSearch)
      let response = await fetch(`${endpoint}?key=${encodeURIComponent(geminiKey)}`, {
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

      // If 400 or tool error, retry without tools on same model
      if (!response.ok && response.status !== 404) {
        response = await fetch(`${endpoint}?key=${encodeURIComponent(geminiKey)}`, {
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
        lastErrorStatus = `${response.status} (${modelName}): ${errText.slice(0, 150)}`;
        continue; // Try next model in fallback list
      }

      const json = await response.json();
      const text =
        json?.candidates?.[0]?.content?.parts
          ?.map((part: any) => part.text || "")
          .join("\n")
          .trim() || "";
      const parsed = extractJsonObject(text);
      if (!parsed) {
        lastErrorStatus = `GEMINI_INVALID_JSON (${modelName})`;
        continue;
      }

      const sourceUrls = normalizeStringList(parsed.source_urls);
      const groundingUrls =
        json?.candidates?.[0]?.groundingMetadata?.groundingChunks
          ?.map((chunk: any) => chunk?.web?.uri)
          ?.filter((uri: unknown) => typeof uri === "string") || [];

      return {
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
    } catch (err: any) {
      lastErrorStatus = err?.name === "AbortError" ? `TIMEOUT (${modelName})` : `EXCEPTION (${modelName})`;
    } finally {
      clearTimeout(timeout);
    }
  }

  return unavailableAi("GEMINI_HTTP_ERROR", `Gemini request failed: ${lastErrorStatus}`);
}

function summarize(matches: VisualMatch[]): Record<string, number> {
  const summaryCounts = { instagram: 0, tiktok: 0, youtube: 0, facebook: 0, other: 0 };
  for (const match of matches) {
    summaryCounts[match.classified_platform] += 1;
  }
  return summaryCounts;
}

function uniqueMatches(matches: VisualMatch[]): VisualMatch[] {
  const map = new Map<string, VisualMatch>();
  for (const match of matches) {
    const key = match.link || `${match.title}|${match.classified_platform}`;
    const existing = map.get(key);
    if (!existing || (match.match_type === "exact_match" && existing.match_type !== "exact_match")) {
      map.set(key, match);
    }
  }
  return Array.from(map.values()).map((match, index) => ({ ...match, position: index + 1 }));
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
    const { image_base64, image_url, max_results = 15, ocr_query } = body;
    const frameList = [
      ...(Array.isArray(body.image_frames_base64) ? body.image_frames_base64 : []),
      ...(image_base64 ? [image_base64] : []),
    ]
      .filter((frame) => typeof frame === "string" && frame.length > 0)
      .slice(0, 3);

    if (frameList.length === 0 && !image_url) {
      return new Response(
        JSON.stringify({
          error: "Invalid request. Must provide image_base64, image_frames_base64, or image_url.",
          code: "BAD_INPUT",
          ai_analysis: unavailableAi("BAD_INPUT", "No frame was supplied for AI review."),
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const serpApiKey = Deno.env.get("SERPAPI_KEY");
    const geminiKey = Deno.env.get("gm_key") || Deno.env.get("GM_KEY");
    const allMatches: VisualMatch[] = [];
    const errors: string[] = [];

    if (serpApiKey && serpApiKey.trim().length > 0) {
      for (const frame of frameList.length > 0 ? frameList : [undefined]) {
        const result = await fetchSerpApiMatches(
          serpApiKey,
          frame,
          frame ? undefined : image_url,
          Math.max(3, Math.ceil(max_results / Math.max(1, frameList.length || 1))),
        );
        allMatches.push(...result.matches);
        if (result.error) errors.push(`${result.error.code}: ${result.error.message}`);
      }

      const links = new Set(allMatches.map((match) => match.link));
      allMatches.push(
        ...(await fetchOcrMatches(serpApiKey, ocr_query, max_results - allMatches.length, links)),
      );
    } else {
      errors.push("MISSING_SERPAPI_KEY: SerpApi exact visual search is not configured.");
    }

    const matches = uniqueMatches(allMatches).slice(0, max_results);
    const aiAnalysis = await fetchGeminiAnalysis(geminiKey, frameList, ocr_query, matches);
    const status = matches.length > 0 || aiAnalysis.status === "success" ? "success" : "failed";
    const responseBody: Record<string, unknown> = {
      status,
      total_matches: matches.length,
      summary: summarize(matches),
      matches,
      ai_analysis: aiAnalysis,
    };

    if (status === "failed") {
      responseBody.error = errors[0] || aiAnalysis.summary || "No online evidence returned.";
      responseBody.code = errors.length > 0 ? "ONLINE_EVIDENCE_UNAVAILABLE" : aiAnalysis.error_code;
    }

    return new Response(JSON.stringify(responseBody), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        error: "Internal Edge Function Error",
        details: err?.message || String(err),
        code: "EDGE_FUNCTION_EXCEPTION",
        ai_analysis: unavailableAi("EDGE_FUNCTION_EXCEPTION", "AI review failed inside the proxy."),
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
