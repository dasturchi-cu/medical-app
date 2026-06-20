import '../../services/media_url_resolver.dart';

int _readNonNegativeMoney(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value < 0 ? 0 : value;
  if (value is double) {
    if (value.isNaN || value.isInfinite) return 0;
    return value.round().clamp(0, 1 << 62);
  }
  if (value is num) return value.round().clamp(0, 1 << 62);
  final s = value.toString().trim();
  if (s.isEmpty) return 0;
  final normalized = s
      .replaceAll(' ', '')
      .replaceAll("'", '')
      .replaceAll(',', '')
      .replaceAll("so'm", '')
      .replaceAll('sum', '')
      .replaceAll('\$', '');
  final asDouble = double.tryParse(normalized);
  if (asDouble != null) {
    if (asDouble.isNaN || asDouble.isInfinite) return 0;
    return asDouble.round().clamp(0, 1 << 62);
  }
  return int.tryParse(normalized) ?? 0;
}

class BookItemModel {
  const BookItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.fileUrl,
    required this.fileMime,
    required this.author,
    required this.categoryName,
    required this.pageCount,
    this.priceUzs = 0,
    this.purchaseContactUrl = '',
  });

  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final String fileUrl;
  final String fileMime;
  final String author;
  final String categoryName;
  final int pageCount;
  final int priceUzs;
  final String purchaseContactUrl;

  bool get isPaid => priceUzs > 0;

  factory BookItemModel.fromJson(Map<String, dynamic> json) {
    final priceRaw = json['price_uzs'] ??
        json['priceUzs'] ??
        json['price'] ??
        json['narx_uzs'] ??
        json['narxUzs'];
    return BookItemModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      coverImageUrl: MediaUrlResolver.resolveStoredMediaUrl(
        (json['cover_image_url'] ?? json['coverImageUrl'] ?? '').toString(),
      ),
      fileUrl: MediaUrlResolver.resolveStoredMediaUrl(
        (json['file_url'] ?? json['fileUrl'] ?? '').toString(),
      ),
      fileMime: (json['file_mime'] ?? json['fileMime'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      categoryName: (json['category_name'] ?? json['categoryName'] ?? '').toString(),
      pageCount: int.tryParse((json['page_count'] ?? '0').toString()) ?? 0,
      priceUzs: _readNonNegativeMoney(priceRaw),
      purchaseContactUrl:
          (json['purchase_contact_url'] ?? json['purchaseContactUrl'] ?? '').toString(),
    );
  }
}

class BookProgressModel {
  const BookProgressModel({
    required this.bookId,
    required this.pageNo,
    required this.progressPercent,
  });

  final String bookId;
  final int pageNo;
  final double progressPercent;

  factory BookProgressModel.fromJson(Map<String, dynamic> json) {
    return BookProgressModel(
      bookId: (json['book_id'] ?? '').toString(),
      pageNo: int.tryParse((json['page_no'] ?? '1').toString()) ?? 1,
      progressPercent: double.tryParse((json['progress_percent'] ?? '0').toString()) ?? 0,
    );
  }
}

class LessonAssetModel {
  const LessonAssetModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.previewImageUrl,
    required this.lessonId,
    required this.orderNo,
  });

  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileType;
  final String previewImageUrl;
  final String lessonId;
  final int orderNo;

  factory LessonAssetModel.fromJson(Map<String, dynamic> json) {
    return LessonAssetModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      fileUrl: MediaUrlResolver.resolveStoredMediaUrl((json['file_url'] ?? '').toString()),
      fileType: (json['file_type'] ?? 'pdf').toString(),
      previewImageUrl: MediaUrlResolver.resolveStoredMediaUrl(
        (json['preview_image_url'] ?? '').toString(),
      ),
      lessonId: (json['lesson_id'] ?? '').toString(),
      orderNo: int.tryParse((json['order_no'] ?? '1').toString()) ?? 1,
    );
  }
}
