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

  static const String projects = '/projects';
  static String projectById(String id) => '/projects/$id';
  static String projectContributors(String id) => '/projects/$id/contributors';
  static String projectMembers(String id) => '/projects/$id/members';
  static String projectTeams(String id) => '/projects/$id/teams';
  static String joinTeam(String projectId, String teamId) =>
      '/projects/$projectId/teams/$teamId/join';


  static const String contributeMpesa = '/contributions/mpesa';
  static const String contributeAirtel = '/contributions/airtel';
  static String contributionStatus(String reference) =>
      '/contributions/status/$reference';
  static const String myContributions = '/users/me/contributions';

  static const Duration pollInterval = Duration(seconds: 3);
  static const int pollMaxAttempts = 40; // 2 minutes max
}
