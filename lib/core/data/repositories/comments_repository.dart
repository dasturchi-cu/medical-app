import '../models/comment_models.dart';

abstract class CommentsRepository {
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
    bool forceRefresh = false,
  });

  Future<void> addComment({
    required String courseKey,
    required String userId,
    required String authorName,
    required String text,
  });

  Future<void> addReply({
    required String commentId,
    required String userId,
    required String authorName,
    required String text,
    String courseKey = '',
  });

  Future<AppCommentItem?> toggleLike({
    required String commentId,
    required String userId,
    String courseKey = '',
    bool likedByMe = false,
    int likesCount = 0,
  });

  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 6),
  });
}
