import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const SOCIALCRAWL_BASE = 'https://www.socialcrawl.dev/v1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { url, platform } = await req.json();

    if (!url || !platform) {
      return new Response(
        JSON.stringify({ status: 'error', message: 'url and platform are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Validate platform — only Instagram and TikTok are supported via SocialCrawl post endpoints
    const allowedPlatforms = ['instagram', 'tiktok'];
    if (!allowedPlatforms.includes(platform.toLowerCase())) {
      return new Response(
        JSON.stringify({ status: 'unsupported', message: `Platform '${platform}' is not supported by the SocialCrawl post endpoint` }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Read API key ONLY server-side — never exposed to client
    const apiKey = Deno.env.get('socialcrawl_api');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ status: 'error', message: 'SocialCrawl configuration missing' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Build the correct SocialCrawl endpoint
    const platformEndpoint = platform.toLowerCase() === 'instagram'
      ? `${SOCIALCRAWL_BASE}/instagram/post`
      : `${SOCIALCRAWL_BASE}/tiktok/post`;

    const queryUrl = `${platformEndpoint}?url=${encodeURIComponent(url)}`;

    const crawlResponse = await fetch(queryUrl, {
      method: 'GET',
      headers: {
        'x-api-key': apiKey,
        'Accept': 'application/json',
      },
      // 8 second timeout
      signal: AbortSignal.timeout(8000),
    });

    if (!crawlResponse.ok) {
      // Don't leak API key or internal error details
      return new Response(
        JSON.stringify({ status: 'api_error', message: `SocialCrawl returned status ${crawlResponse.status}` }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const crawlData = await crawlResponse.json();

    if (!crawlData.success || !crawlData.data) {
      return new Response(
        JSON.stringify({ status: 'not_found', message: 'Post not found or unavailable' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const data = crawlData.data;

    // === NORMALISE RESPONSE TO FLAT STRUCTURE ===
    // SocialCrawl unified schema:
    //   { success, platform, data: { author: { username, followers, full_name? },
    //     engagement: { likes, comments, views?, shares?, engagement_rate },
    //     metadata: { taken_at? (Instagram Unix ts), published_at? (TikTok ISO), content? { text } }
    //   }}

    // Instagram: taken_at is Unix timestamp (seconds)
    // TikTok: published_at is ISO string (unified schema)
    let platformPostTimestamp: string | null = null;
    if (data.metadata?.taken_at) {
      // Convert Unix timestamp to ISO string
      const ts = Number(data.metadata.taken_at);
      if (!isNaN(ts) && ts > 0) {
        platformPostTimestamp = new Date(ts * 1000).toISOString();
      }
    } else if (data.metadata?.published_at) {
      platformPostTimestamp = String(data.metadata.published_at);
    } else if (data.taken_at) {
      // Fallback: some endpoints surface taken_at at root level
      const ts = Number(data.taken_at);
      if (!isNaN(ts) && ts > 0) {
        platformPostTimestamp = new Date(ts * 1000).toISOString();
      }
    }

    const authorUsername = data.author?.username ?? data.author?.handle ?? null;
    const authorDisplayName = data.author?.full_name ?? data.author?.nickname ?? data.author?.name ?? null;
    const captionText = data.metadata?.content?.text ?? data.caption?.text ?? data.desc ?? null;

    const engagement = data.engagement ?? {};
    const likesCount = engagement.likes ?? null;
    const commentsCount = engagement.comments ?? null;
    const viewsCount = engagement.views ?? engagement.view_count ?? null;
    const sharesCount = engagement.shares ?? engagement.share_count ?? null;

    const normalized = {
      platform: platform.toLowerCase(),
      url,
      platform_post_timestamp: platformPostTimestamp,
      author_username: authorUsername,
      author_display_name: authorDisplayName,
      caption_text: captionText ? String(captionText).substring(0, 300) : null,
      likes_count: likesCount !== null ? Number(likesCount) : null,
      comments_count: commentsCount !== null ? Number(commentsCount) : null,
      views_count: viewsCount !== null ? Number(viewsCount) : null,
      shares_count: sharesCount !== null ? Number(sharesCount) : null,
      retrieved_at: new Date().toISOString(),
    };

    return new Response(
      JSON.stringify({ status: 'success', data: normalized }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );

  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    // Do NOT include stack traces or API key in error responses
    return new Response(
      JSON.stringify({ status: 'error', message: message.includes('timeout') ? 'Request timed out' : 'Internal error' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
