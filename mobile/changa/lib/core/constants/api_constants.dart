class ApiConstants {
  ApiConstants._();

  
static const String baseUrl = 'http://192.168.1.193:8000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);


  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';

  // A bare GET/POST /projects was never defined server-side — creation and
  // listing live under /chamas/{chama_id}/projects, and the cross-chama
  // feed is /projects/mine. /projects/{id}/members, /teams and the
  // team-join route never existed server-side either. See API-01 in
  // docs/Changa_Engineering_audit.md.
  static const String myProjects = '/projects/mine';
  static String projectById(String id) => '/projects/$id';
  static String projectContributors(String id) => '/projects/$id/contributors';


  static const String contributeMpesa = '/contributions/mpesa';
  static const String contributeAirtel = '/contributions/airtel';
  static String contributionStatus(String reference) =>
      '/contributions/status/$reference';
  static const String myContributions = '/users/me/contributions';

  static const Duration pollInterval = Duration(seconds: 3);
  static const int pollMaxAttempts = 40; // 2 minutes max
}
