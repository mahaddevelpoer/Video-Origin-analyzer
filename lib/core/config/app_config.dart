/// Central Configuration for Video Origin Analyzer
/// Developer: Mahad and Mehdi Developers
class AppConfig {
  static const String appName = 'Video Origin Analyzer';
  static const String developerName = 'Mahad and Mehdi Developers';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String forensicEngineVersion = '1.0.0';

  // Free Tier Policy
  static const int freeDailyAnalysisLimit = 2;

  // Disclaimer
  static const String legalDisclaimer =
      'The analysis provided by this application is an estimate based on available technical and visual evidence. '
      'It cannot guarantee the original source of every video, particularly when media has been edited, re-encoded, screen-recorded, or had metadata removed.';

  static const String privacyStatement =
      'Local forensic analysis runs on your device. Optional online visual search sends only selected representative frames through the search proxy; original video files are not uploaded.';
}
