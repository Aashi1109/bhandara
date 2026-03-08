class Api {
  // Auth endpoints
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String logout = '/auth/logout';
  static const String googleSignIn = '/auth/oauth/signin-with-id-token';
  static const String session = '/auth/session';

  // User endpoints
  static const String users = '/users';
  static String updateUser(String id) => '/users/$id';
  static String getUserById(String id) => '/users/$id';
  static String getUserByEmail(String email) => '/users/email/$email';
  static const String getUserByQuery = '/users/query';

  // Event endpoints
  static const String events = '/events';

  // Thread endpoints
  static const String threads = '/threads';
  static String threadMessages(String threadId) =>
      '/threads/$threadId/messages';
  static String eventThreads(String eventId) => '/events/$eventId/threads';

  // Media endpoints
  static const String getSignedUrl = '/media/get-signed-upload-url';
  static const String getPublicUrl = '/media/get-public-upload-url';
  static String media(String id) => '/media/$id';

  // Tag endpoints
  static const String tags = '/tags';
}
