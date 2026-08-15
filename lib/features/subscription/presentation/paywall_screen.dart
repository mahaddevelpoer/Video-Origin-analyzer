import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  Package? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final subService = ref.read(subscriptionServiceProvider);
    await subService.fetchOfferings();
    if (mounted) {
      setState(() {
        final offerings = subService.currentOfferings;
        if (offerings != null && offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
          _selectedPackage = offerings.current!.availablePackages.first;
        }
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.purchasePackage(_selectedPackage!);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _statusMessage = 'Pro Subscription successfully activated!';
        } else {
          _statusMessage = 'Purchase could not be completed.';
        }
      });
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.restorePurchases();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _statusMessage = 'Purchases restored successfully!';
        } else {
          _statusMessage = 'No active Pro subscription found to restore.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subService = ref.watch(subscriptionServiceProvider);
    final isPro = subService.isProActive;
    final offerings = subService.currentOfferings;
    final packages = offerings?.current?.availablePackages ?? [];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.youtubeRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'VIDEO ORIGIN ANALYZER PRO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock Unlimited Local Media Forensics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 24),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPro
                        ? AppColors.strengthStrong.withAlpha(25)
                        : AppColors.strengthWeak.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPro ? AppColors.strengthStrong : AppColors.strengthWeak,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPro ? AppColors.strengthStrong : AppColors.strengthWeak,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildBenefitRow('Unlimited Video Origin Analyses (No daily 2-video cap)'),
              _buildBenefitRow('100% Ad-Free Experience'),
              _buildBenefitRow('Full Technical Evidence Breakdown Reports'),
              _buildBenefitRow('PDF Forensic Report Exporting'),
              _buildBenefitRow('Priority Access to Signature Updates'),
              const SizedBox(height: 24),

              if (packages.isNotEmpty) ...[
                const Text(
                  'SELECT SUBSCRIPTION PLAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ...packages.map((pkg) {
                  final isSelected = _selectedPackage?.identifier == pkg.identifier;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPackage = pkg),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.youtubeRed : AppColors.lightBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg.storeProduct.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pkg.storeProduct.description,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Text(
                            pkg.storeProduct.priceString,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.youtubeRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Pro Subscription (Dynamic RevenueCat Offering)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Offerings load dynamically from RevenueCat SDK.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handlePurchase,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isPro ? 'PRO IS ACTIVE' : 'START PRO SUBSCRIPTION'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _handleRestore,
                child: const Text('RESTORE PURCHASES'),
              ),

              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Mahad and Mehdi Developers • Privacy & Terms Apply',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.strengthStrong, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
