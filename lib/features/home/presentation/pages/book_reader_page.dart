import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/books_state.dart';

class BookReaderPage extends ConsumerStatefulWidget {
  const BookReaderPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage> {
  int _lastPage = 1;
  int _totalPages = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksFeedProvider).valueOrNull ?? const [];
    final matched = books.where((e) => e.id == widget.bookId);
    final book = matched.isEmpty ? null : matched.first;
    final userId = ref.watch(authControllerProvider).userId ?? '';
    if (book == null) {
      return const Scaffold(body: Center(child: Text('Kitob topilmadi')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: _buildPdfViewer(book.fileUrl, userId),
    );
  }

  Widget _buildPdfViewer(String fileUrl, String userId) {
    final normalized = fileUrl.trim();
    final isPdfDataUrl = normalized.startsWith('data:application/pdf');
    return FutureBuilder<Uint8List>(
      future: _resolvePdfBytes(normalized, isPdfDataUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text(
              snapshot.error is Exception ? (snapshot.error as Exception).toString().replaceFirst('Exception: ', '') : "PDF faylni ochib bo'lmadi.",
            ),
          );
        }
        return SfPdfViewer.memory(
          snapshot.data!,
          canShowPaginationDialog: true,
          onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
          onPageChanged: (details) => _onPageChanged(details, userId),
        );
      },
    );
  }

  Future<Uint8List> _resolvePdfBytes(String value, bool isDataUrl) async {
    if (isDataUrl) {
      final comma = value.indexOf(',');
      if (comma <= 0) throw Exception("PDF formati noto'g'ri.");
      try {
        return base64Decode(value.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
      } catch (_) {
        throw Exception("PDF faylni o'qib bo'lmadi.");
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null) throw Exception("PDF URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('bucket not found')) {
        throw Exception("Storage bucket topilmadi. Admin panelda `content-assets` bucketni yarating.");
      }
      throw Exception("PDF yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }

  void _onPageChanged(PdfPageChangedDetails details, String userId) {
    _lastPage = details.newPageNumber;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (userId.isEmpty) return;
      final percent = _totalPages > 0 ? ((_lastPage / _totalPages) * 100).clamp(0, 100).toDouble() : 0.0;
      unawaited(
        ref.read(booksRepositoryProvider).upsertProgress(
              userId: userId,
              bookId: widget.bookId,
              pageNo: _lastPage,
              progressPercent: percent,
            ),
      );
    });
  }
}
