class ApiConstants {
  ApiConstants._();

  // ── Base URL ──────────────────────────────────────────────────────────────
  // Android emulator → 10.0.2.2
  // Physical device  → your machine's LAN IP e.g. 192.168.1.105
  // Production       → https://api.changa.co.ke
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';

  // ── Projects ──────────────────────────────────────────────────────────────
  static const String projects = '/projects';
  static String projectById(String id) => '/projects/$id';
  static String projectContributors(String id) => '/projects/$id/contributors';
  static String projectMembers(String id) => '/projects/$id/members';
  static String projectTeams(String id) => '/projects/$id/teams';
  static String joinTeam(String projectId, String teamId) =>
      '/projects/$projectId/teams/$teamId/join';

  // ── Payments ──────────────────────────────────────────────────────────────
  static const String contributeMpesa = '/contributions/mpesa';
  static const String contributeAirtel = '/contributions/airtel';
  static String contributionStatus(String reference) =>
      '/contributions/status/$reference';
  static const String myContributions = '/users/me/contributions';

  // ── Polling ───────────────────────────────────────────────────────────────
  static const Duration pollInterval = Duration(seconds: 3);
  static const int pollMaxAttempts = 40; // 2 minutes max
}
