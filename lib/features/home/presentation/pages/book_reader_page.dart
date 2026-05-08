import 'dart:async';

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
      body: SfPdfViewer.network(
        book.fileUrl,
        canShowPaginationDialog: true,
        onDocumentLoaded: (details) {
          _totalPages = details.document.pages.count;
        },
        onPageChanged: (details) {
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
        },
      ),
    );
  }
}
