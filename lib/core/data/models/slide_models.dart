class HomeSlideItem {
  const HomeSlideItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonText,
    required this.courseId,
    required this.orderNo,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String buttonText;
  final String? courseId;
  final int orderNo;

  factory HomeSlideItem.fromJson(Map<String, dynamic> json) {
    return HomeSlideItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      buttonText: (json['button_text'] ?? 'Boshlash').toString(),
      courseId: json['course_id']?.toString(),
      orderNo: int.tryParse((json['order_no'] ?? '1').toString()) ?? 1,
    );
  }
}
