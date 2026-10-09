import 'save_service.dart';

/// Monétisation : publicités récompensées et abonnement Premium.
///
/// Version de démonstration : la publicité et l'achat sont simulés, rien n'est
/// facturé. Pour la production, brancher google_mobile_ads (RewardedAd) dans
/// [showRewardedAd] et in_app_purchase dans [subscribe].
class MonetizationService {
  MonetizationService._();
  static final MonetizationService instance = MonetizationService._();

  static const bool isDemo = true;
  static const String premiumPrice = '4,99 € / mois';
  static const Duration demoAdDuration = Duration(seconds: 5);

  final SaveService _save = SaveService();
  bool premium = false;

  Future<void> load() async {
    premium = await _save.premium();
  }

  /// Retourne true quand la récompense est acquise.
  /// Les abonnés Premium l'obtiennent sans publicité.
  Future<bool> showRewardedAd(Future<bool> Function() presentDemoAd) async {
    if (premium) return true;
    return presentDemoAd();
  }

  Future<bool> subscribe() async {
    premium = true;
    await _save.setPremium(true);
    return true;
  }

  Future<void> cancelSubscription() async {
    premium = false;
    await _save.setPremium(false);
  }
}
