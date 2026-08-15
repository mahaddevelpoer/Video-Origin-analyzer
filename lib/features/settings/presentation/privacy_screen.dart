import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Privacy & Data Handling Policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.youtubeRed),
                    ),
                    child: const Icon(Icons.security, color: AppColors.youtubeRed, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local-First Privacy Architecture',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Zero Video Upload Guarantee',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.youtubeRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildPrivacyPoint(
                title: '1. On-Device Forensic Processing',
                description:
                    'All video metadata, container parsing, codec inspection, audio analysis, visual signatures, and re-encoding detection run 100% locally on your physical device. Original video files NEVER leave your phone.',
              ),
              _buildPrivacyPoint(
                title: '2. Online Evidence Data Flow (SerpApi Proxy)',
                description:
                    'When Online Visual Search is enabled, a single selected representative video frame (compressed JPEG < 500KB) is sent in-memory through our secure Supabase Edge Function proxy to SerpApi Google Lens. The frame is processed in memory to fetch matching web links and is IMMEDIATELY discarded. Frames are NEVER stored permanently in Supabase, databases, or cloud storage.',
              ),
              _buildPrivacyPoint(
                title: '3. No Permanent Database / No Cloud Storage',
                description:
                    'This application deliberately contains NO Cloud Firestore, NO Realtime Database, NO Firebase Storage, and NO custom server storage backend. All analysis history remains strictly saved in local device storage.',
              ),
              _buildPrivacyPoint(
                title: '4. Authentication & Licensing',
                description:
                    'Firebase Authentication is utilized strictly to verify user identity, while RevenueCat manages Pro subscription entitlement status securely.',
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: const Text(
                  AppConfig.privacyStatement,
                  style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Mahad and Mehdi Developers • Video Origin Analyzer',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPoint({required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
