class AppConstants {
  AppConstants._();

  static const String appName = 'Changa';

  // Secure storage keys
  static const String accessTokenKey = 'changa_access_token';
  static const String refreshTokenKey = 'changa_refresh_token';
  static const String userIdKey = 'changa_user_id';

  // Shared preferences keys
  static const String onboardingDoneKey = 'onboarding_done';
  static const String themeModeKey = 'theme_mode';

  // Asset paths
  static const String logoPath = 'assets/images/logo.png';
  static const String splashAnimPath = 'assets/animations/splash.json';

  // Currency
  static const String currency = 'KES';

  // Quick contribution amounts (KES)
  static const List<double> quickAmounts = [50, 100, 200, 500, 1000, 2000];
}
