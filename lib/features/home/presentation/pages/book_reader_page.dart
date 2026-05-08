import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (isPdfDataUrl) {
      final comma = normalized.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(normalized.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
          return SfPdfViewer.memory(
            bytes,
            canShowPaginationDialog: true,
            onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
            onPageChanged: (details) => _onPageChanged(details, userId),
          );
        } catch (_) {
          return const Center(child: Text("PDF faylni o'qib bo'lmadi."));
        }
      }
    }
    return SfPdfViewer.network(
      normalized,
      canShowPaginationDialog: true,
      onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
      onPageChanged: (details) => _onPageChanged(details, userId),
    );
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
