// Supabase Edge Function: visual-search
// Secure Proxy for SerpApi Google Lens API
// Developer: Mahad and Mehdi Developers - Video Origin Analyzer

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface RequestPayload {
  image_base64?: string;
  image_url?: string;
  max_results?: number;
}

interface VisualMatch {
  position: number;
  title: string;
  link: string;
  domain: string;
  classified_platform: "instagram" | "tiktok" | "youtube" | "facebook" | "other";
  thumbnail?: string;
  source?: string;
  match_type?: "exact_match" | "visual_match";
  date?: string;
}

function classifyDomain(
  urlString: string
): "instagram" | "tiktok" | "youtube" | "facebook" | "other" {
  try {
    const parsed = new URL(urlString);
    const host = parsed.hostname.toLowerCase();

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
    const parsed = new URL(urlString);
    return parsed.hostname.toLowerCase();
  } catch (_) {
    return "unknown";
  }
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed. Use POST." }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Read SerpApi Key securely from environment secret
    const serpApiKey = Deno.env.get("SERPAPI_KEY");
    if (!serpApiKey || serpApiKey.trim() === "") {
      return new Response(
        JSON.stringify({
          error: "SERPAPI_KEY secret is not configured on Supabase Edge Function.",
          code: "MISSING_SERPAPI_KEY",
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Parse payload
    const body: RequestPayload = await req.json().catch(() => ({}));
    const { image_base64, image_url, max_results = 15 } = body;

    if (!image_base64 && !image_url) {
      return new Response(
        JSON.stringify({
          error: "Invalid request. Must provide either image_base64 or image_url.",
          code: "BAD_INPUT",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let searchImageId: string | null = null;
    let queryUrl: string = "";

    // 3. Obtain image_id from SerpApi if base64 provided
    if (image_base64) {
      const cleanBase64 = image_base64.replace(/^data:image\/\w+;base64,/, "");
      const binaryData = Uint8Array.from(atob(cleanBase64), (c) => c.charCodeAt(0));

      if (binaryData.length > 500 * 1024) {
        return new Response(
          JSON.stringify({
            error: "Image frame size exceeds 500KB limit for visual search.",
            code: "FRAME_TOO_LARGE",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const formData = new FormData();
      const blob = new Blob([binaryData], { type: "image/jpeg" });
      formData.append("image", blob, "frame.jpg");
      formData.append("api_key", serpApiKey);

      const uploadRes = await fetch("https://serpapi.com/image", {
        method: "POST",
        body: formData,
      });

      if (!uploadRes.ok) {
        const errText = await uploadRes.text();
        return new Response(
          JSON.stringify({
            error: `SerpApi image upload failed: ${uploadRes.status}`,
            details: errText,
            code: "SERPAPI_UPLOAD_FAILED",
          }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const uploadJson = await uploadRes.json();
      searchImageId = uploadJson.image_id;

      if (!searchImageId) {
        return new Response(
          JSON.stringify({
            error: "SerpApi did not return an image_id.",
            code: "SERPAPI_NO_IMAGE_ID",
          }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      queryUrl = `https://serpapi.com/search.json?engine=google_lens&image_id=${encodeURIComponent(
        searchImageId
      )}&api_key=${encodeURIComponent(serpApiKey)}`;
    } else if (image_url) {
      queryUrl = `https://serpapi.com/search.json?engine=google_lens&url=${encodeURIComponent(
        image_url
      )}&api_key=${encodeURIComponent(serpApiKey)}`;
    }

    // 4. Query SerpApi Google Lens endpoint
    const lensRes = await fetch(queryUrl);
    if (!lensRes.ok) {
      const errText = await lensRes.text();
      return new Response(
        JSON.stringify({
          error: `SerpApi Google Lens search failed with status ${lensRes.status}`,
          details: errText,
          code: "SERPAPI_SEARCH_FAILED",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const lensData = await lensRes.json();
    // SerpApi separates pages that contain the exact image from merely related
    // visual results. Never promote a related result to an exact match.
    const exactMatches = lensData.exact_matches || lensData.exact_match || [];
    const rawMatches = [
      ...exactMatches.map((item: any) => ({ ...item, __matchType: "exact_match" })),
      ...(lensData.visual_matches || []).map((item: any) => ({ ...item, __matchType: "visual_match" })),
    ];

    // 5. Parse and classify domain matches
    const matches: VisualMatch[] = [];
    const summaryCounts = {
      instagram: 0,
      tiktok: 0,
      youtube: 0,
      facebook: 0,
      other: 0,
    };

    let count = 0;
    for (const item of rawMatches) {
      if (count >= max_results) break;
      const link = item.link || "";
      if (!link) continue;

      const classified = classifyDomain(link);
      const domain = extractDomain(link);

      summaryCounts[classified]++;

      matches.push({
        position: item.position || count + 1,
        title: item.title || "Related Visual Result",
        link: link,
        domain: domain,
        classified_platform: classified,
        thumbnail: item.thumbnail || item.source_icon,
        source: item.source,
        match_type: item.__matchType,
        date: item.date || item.snippet_date,
      });

      count++;
    }

    return new Response(
      JSON.stringify({
        status: "success",
        total_matches: matches.length,
        summary: summaryCounts,
        matches: matches,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        error: "Internal Edge Function Error",
        details: err?.message || String(err),
        code: "EDGE_FUNCTION_EXCEPTION",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
