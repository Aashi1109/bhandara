class Api {
  // Auth endpoints
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String logout = '/auth/logout';
  static const String googleSignIn = '/auth/oauth/signin-with-id-token';
  static const String session = '/auth/session';
  static const String sessions = '/auth/sessions';

  static String deleteSession(String sessionId) => '/auth/session/$sessionId';

  // User endpoints
  static const String users = '/users';

  static String updateUser(String id) => '/users/$id';

  static String getUserById(String id) => '/users/$id';

  static const String getUserByQuery = '/users/query';

  static String userSettings(String userId) => '/users/$userId/settings';

  static String userInterests(String userId) => '/users/$userId/interests';
  static String userActivity(String userId) => '/users/$userId/activity';
  static String userAchievements(String userId) =>
      '/users/$userId/achievements';
  static String userAchievementProgress(String userId) =>
      '/users/$userId/achievements/progress';
  static const String myUpdates = '/users/me/updates';
  static const String markAllMyUpdatesRead = '/users/me/updates/read-all';
  static String markMyUpdateRead(String activityId) =>
      '/users/me/updates/$activityId/read';

  // Event endpoints
  static const String events = '/events';
  static const String eventMarkers = '/events/markers';

  static String eventById(String eventId) => '/events/$eventId';

  static String eventAction(String eventId, String action) =>
      '/events/$eventId/$action';

  static String verifyEvent(String eventId) => '/events/$eventId/verify';

  static String eventMedia(String eventId, String mediaId) =>
      '/events/$eventId/media/$mediaId';

  // Thread endpoints
  static const String threads = '/threads';

  static String threadById(String threadId) => '/threads/$threadId';

  static String threadMessages(String threadId) =>
      '/threads/$threadId/messages';

  static String threadMessage(String threadId, String messageId) =>
      '/threads/$threadId/messages/$messageId';

  static String threadChildMessages(String threadId, String parentId) =>
      '/threads/$threadId/child-messages/$parentId';

  static String lockThread(String threadId) => '/threads/$threadId/lock';

  static String unlockThread(String threadId) => '/threads/$threadId/unlock';

  static String eventThreads(String eventId) => '/events/$eventId/threads';

  static String eventThreadMessages(String eventId, String threadId) =>
      '/events/$eventId/threads/$threadId/messages';

  // Media endpoints
  static const String getSignedUrl = '/media/get-signed-upload-url';
  static const String getPublicUrl = '/media/get-public-upload-url';
  static const String mediaPublicUrl = '/media/public-url';

  static String media(String id) => '/media/$id';

  // Tag endpoints
  static const String tags = '/tags';

  static String tagById(String tagId) => '/tags/$tagId';

  static String tagSubTags(String tagId) => '/tags/$tagId/sub-tags';

  // Search endpoints
  static const String search = '/search';
  static const String searchSuggestions = '/search/suggestions';

  // Engagement endpoints
  static String engagement(String entityType, String entityId) =>
      '/engagement/$entityType/$entityId';

  static String engagementRating(String entityType, String entityId) =>
      '/engagement/$entityType/$entityId/rating';

  static String engagementRatings(String entityType, String entityId) =>
      '/engagement/$entityType/$entityId/ratings';

  // Save endpoints
  static const String saves = '/saves';

  static String saveEntity(String entityType, String entityId) =>
      '/saves/$entityType/$entityId';
}
