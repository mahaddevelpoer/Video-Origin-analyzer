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
      // 15 second timeout for live scraping
      signal: AbortSignal.timeout(15000),
    });

    if (!crawlResponse.ok) {
      // Don't leak API key or internal error details
      return new Response(
        JSON.stringify({ status: 'api_error', message: `SocialCrawl returned status ${crawlResponse.status}` }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const crawlData = await crawlResponse.json();
    console.log('SocialCrawl Raw Response:', JSON.stringify(crawlData));

    if (!crawlData.success || !crawlData.data) {
      return new Response(
        JSON.stringify({ status: 'not_found', message: 'Post not found or unavailable' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const data = crawlData.data;
    const post = data.post || data;
    const authorObj = post.author || post.user || post.owner || {};
    const metadataObj = post.metadata || {};
    const engagementObj = post.engagement || post.stats || post.metrics || data.computed || {};
    const contentObj = post.content || post.caption || {};

    // Timestamp resolution (taken_at, timestamp, published_at, created_time)
    let platformPostTimestamp: string | null = null;
    const rawTs = metadataObj.taken_at || metadataObj.timestamp || metadataObj.published_at || post.taken_at || post.timestamp || post.published_at || post.create_time || post.created_time;
    if (rawTs) {
      const numTs = Number(rawTs);
      if (!isNaN(numTs) && numTs > 0) {
        const tsInMs = numTs < 10000000000 ? numTs * 1000 : numTs;
        platformPostTimestamp = new Date(tsInMs).toISOString();
      } else if (typeof rawTs === 'string') {
        platformPostTimestamp = rawTs;
      }
    }

    const authorUsername = authorObj.username || authorObj.handle || authorObj.unique_id || post.username || null;
    const authorDisplayName = authorObj.full_name || authorObj.nickname || authorObj.name || null;
    const captionText = contentObj.text || contentObj.caption || post.caption || post.desc || (typeof post.text === 'string' ? post.text : null);

    const likesCount = engagementObj.likes ?? engagementObj.like_count ?? engagementObj.digg_count ?? post.like_count ?? post.likes ?? null;
    const commentsCount = engagementObj.comments ?? engagementObj.comment_count ?? post.comment_count ?? post.comments ?? null;
    const viewsCount = engagementObj.views ?? engagementObj.view_count ?? engagementObj.play_count ?? post.play_count ?? post.view_count ?? null;
    const sharesCount = engagementObj.shares ?? engagementObj.share_count ?? post.share_count ?? post.shares ?? null;

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
    const message = err instanceof Error ? err.message : String(err);
    console.error('social-crawl error:', message);
    return new Response(
      JSON.stringify({ status: 'error', message: message.includes('timeout') ? 'Request timed out' : message }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
