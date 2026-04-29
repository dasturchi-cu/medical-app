class AppCommentItem {
  const AppCommentItem({
    required this.id,
    required this.courseKey,
    required this.userId,
    required this.authorName,
    required this.text,
    required this.likesCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String courseKey;
  final String userId;
  final String authorName;
  final String text;
  final int likesCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory AppCommentItem.fromJson(Map<String, dynamic> json) {
    final rawCreated = (json['created_at'] ?? '').toString();
    return AppCommentItem(
      id: (json['id'] ?? '').toString(),
      courseKey: (json['course_key'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      authorName: (json['author_name'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      likesCount: int.tryParse((json['likes_count'] ?? '0').toString()) ?? 0,
      likedByMe: json['liked_by_me'] == true,
      createdAt: DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now(),
    );
  }
}
