import 'platform_signature.dart';

/// Database of Extensible Platform Signatures for Forensic Media Origin Analysis.
class SignatureDatabase {
  static const PlatformSignature tiktok = PlatformSignature(
    platformId: 'tiktok',
    platformName: 'TikTok',
    knownContainers: ['mp4', 'mov'],
    encoderKeywords: ['tiktok', 'musically', 'ssstik', 'snaptik', 'tt_video', 'byteengine', 'bytedance'],
    metadataKeywords: ['tiktok', 'bytedance', 'musically', 'tt'],
    filenamePatterns: ['tiktok', 'ssstik', 'snaptik', 'tt_', 'musically_'],
    aspectRatios: [
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Vertical Portrait', weight: 20),
    ],
    typicalResolutions: ['1080x1920', '720x1280', '540x960'],
    audioCodecs: ['aac', 'mp3'],
    minBitrateKbps: 800,
    maxBitrateKbps: 6000,
    visualSignatures: ['tiktok_watermark', 'tiktok_ending_card', 'vertical_layout'],
  );

  static const PlatformSignature instagram = PlatformSignature(
    platformId: 'instagram',
    platformName: 'Instagram',
    knownContainers: ['mp4', 'mov'],
    encoderKeywords: ['instagram', 'ig_reel', 'meta', 'facebook', 'lavf', 'ig_story'],
    metadataKeywords: ['instagram', 'ig', 'reels', 'meta'],
    filenamePatterns: ['instagram', 'ig_', 'reel_', 'story_'],
    aspectRatios: [
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Reels/Stories', weight: 15),
      AspectRatioPattern(ratio: 1.0, label: '1:1 Square Feed', weight: 20),
      AspectRatioPattern(ratio: 0.8, label: '4:5 Vertical Feed', weight: 20),
    ],
    typicalResolutions: ['1080x1920', '1080x1080', '1080x1350', '720x1280'],
    audioCodecs: ['aac'],
    minBitrateKbps: 1000,
    maxBitrateKbps: 8000,
    visualSignatures: ['instagram_handle_tag', 'ig_reels_icon', 'story_sticker'],
  );

  static const PlatformSignature youtube = PlatformSignature(
    platformId: 'youtube',
    platformName: 'YouTube',
    knownContainers: ['mp4', 'webm', 'mkv'],
    encoderKeywords: ['youtube', 'goog', 'vp9', 'av1', 'ytdl', 'yt_short', 'google'],
    metadataKeywords: ['youtube', 'google', 'yt', 'shorts'],
    filenamePatterns: ['youtube', 'yt_', 'y2mate', 'yt1s', 'shorts_'],
    aspectRatios: [
      AspectRatioPattern(ratio: 1.7777, label: '16:9 Widescreen Landscape', weight: 25),
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Shorts', weight: 15),
    ],
    typicalResolutions: ['1920x1080', '1280x720', '3840x2160', '1080x1920'],
    audioCodecs: ['aac', 'opus'],
    minBitrateKbps: 1200,
    maxBitrateKbps: 15000,
    visualSignatures: ['yt_shorts_logo', 'subscribe_overlay', 'widescreen_format'],
  );

  static const PlatformSignature facebook = PlatformSignature(
    platformId: 'facebook',
    platformName: 'Facebook',
    knownContainers: ['mp4'],
    encoderKeywords: ['facebook', 'meta', 'fb_video', 'fb_watch'],
    metadataKeywords: ['facebook', 'fb', 'fb_video'],
    filenamePatterns: ['facebook', 'fb_', 'fb_watch_'],
    aspectRatios: [
      AspectRatioPattern(ratio: 1.7777, label: '16:9 Landscape', weight: 15),
      AspectRatioPattern(ratio: 1.0, label: '1:1 Square', weight: 15),
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Reel', weight: 15),
    ],
    typicalResolutions: ['1280x720', '1920x1080', '720x720'],
    audioCodecs: ['aac'],
    minBitrateKbps: 800,
    maxBitrateKbps: 5000,
    visualSignatures: ['fb_watch_logo', 'fb_reactions'],
  );

  static const PlatformSignature snapchat = PlatformSignature(
    platformId: 'snapchat',
    platformName: 'Snapchat',
    knownContainers: ['mp4', 'mov'],
    encoderKeywords: ['snapchat', 'snap', 'snap_inc'],
    metadataKeywords: ['snapchat', 'snap'],
    filenamePatterns: ['snapchat', 'snap_', 'Snapchat-'],
    aspectRatios: [
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Fullscreen Vertical', weight: 25),
    ],
    typicalResolutions: ['1080x1920', '720x1280'],
    audioCodecs: ['aac'],
    minBitrateKbps: 1000,
    maxBitrateKbps: 6000,
    visualSignatures: ['snapchat_timestamp', 'snap_caption_bar'],
  );

  static const PlatformSignature whatsapp = PlatformSignature(
    platformId: 'whatsapp',
    platformName: 'WhatsApp',
    knownContainers: ['mp4'],
    encoderKeywords: ['whatsapp', 'wa_video', 'lavf', 'handbrake'],
    metadataKeywords: ['whatsapp', 'wa'],
    filenamePatterns: ['VID-', 'WA', 'WhatsApp Video'],
    aspectRatios: [
      AspectRatioPattern(ratio: 0.5625, label: '9:16 Vertical', weight: 10),
      AspectRatioPattern(ratio: 1.7777, label: '16:9 Landscape', weight: 10),
    ],
    typicalResolutions: ['640x1152', '480x848', '848x480', '1280x720'],
    audioCodecs: ['aac'],
    minBitrateKbps: 200,
    maxBitrateKbps: 1500, // WhatsApp aggressive compression
    visualSignatures: ['wa_compressed'],
  );

  /// Primary Original Source Candidate Signatures (Strictly TikTok, Instagram, YouTube)
  static List<PlatformSignature> get primarySignatures => [
        tiktok,
        instagram,
        youtube,
      ];

  static List<PlatformSignature> get allSignatures => [
        tiktok,
        instagram,
        youtube,
        facebook,
        snapchat,
        whatsapp,
      ];
}
