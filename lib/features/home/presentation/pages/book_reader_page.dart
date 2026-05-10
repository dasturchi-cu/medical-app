import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
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

class _BookReaderPageState extends ConsumerState<BookReaderPage>
    with WidgetsBindingObserver {
  static const int _saveEveryPages = 3;
  static const int _maxForwardJumpPages = 2;
  final PdfViewerController _pdfController = PdfViewerController();
  int _lastPage = 1;
  int _initialPage = 1;
  int _maxReachedPage = 1;
  int _totalPages = 0;
  Timer? _debounce;
  Future<Uint8List>? _pdfBytesFuture;
  String? _loadedUrl;
  String _userId = '';
  bool _restoringProgress = true;
  bool _progressRequestStarted = false;
  bool _isSaving = false;
  int _lastSavedPage = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _protectScreen();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_flushProgressNow());
    WidgetsBinding.instance.removeObserver(this);
    _clearScreenProtection();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_flushProgressNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksFeedProvider).valueOrNull ?? const [];
    final matched = books.where((e) => e.id == widget.bookId);
    final book = matched.isEmpty ? null : matched.first;
    _userId = ref.watch(authControllerProvider).userId ?? '';
    if (book == null) {
      return const Scaffold(body: Center(child: Text('Kitob topilmadi')));
    }
    _ensurePdfFuture(book.fileUrl);
    _ensureProgressLoaded();
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: _buildPdfViewer(),
    );
  }

  Widget _buildPdfViewer() {
    return FutureBuilder<Uint8List>(
      future: _pdfBytesFuture,
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
          controller: _pdfController,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          enableTextSelection: false,
          canShowPaginationDialog: false,
          onDocumentLoaded: (details) {
            _totalPages = details.document.pages.count;
            final safePage = _initialPage.clamp(1, _totalPages);
            if (safePage > 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _pdfController.jumpToPage(safePage);
              });
            }
            _lastPage = safePage;
            _lastSavedPage = safePage;
            _maxReachedPage = safePage;
            _restoringProgress = false;
          },
          onPageChanged: _onPageChanged,
        );
      },
    );
  }

  void _ensurePdfFuture(String fileUrl) {
    final normalized = fileUrl.trim();
    if (_loadedUrl == normalized && _pdfBytesFuture != null) return;
    _loadedUrl = normalized;
    final isPdfDataUrl = normalized.startsWith('data:application/pdf');
    _pdfBytesFuture = _resolvePdfBytes(normalized, isPdfDataUrl);
  }

  Future<void> _ensureProgressLoaded() async {
    if (_userId.isEmpty || !_restoringProgress || _progressRequestStarted) return;
    _progressRequestStarted = true;
    try {
      final progress = await ref
          .read(booksRepositoryProvider)
          .fetchProgress(userId: _userId);
      if (!mounted) return;
      final item = progress.where((e) => e.bookId == widget.bookId).toList();
      if (item.isNotEmpty) {
        _initialPage = item.first.pageNo > 0 ? item.first.pageNo : 1;
        _maxReachedPage = _initialPage;
      }
    } catch (_) {
      // Keep default page=1
    }
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

  void _onPageChanged(PdfPageChangedDetails details) {
    final nextPage = details.newPageNumber;
    final maxAllowed = _maxReachedPage + _maxForwardJumpPages;
    if (!_restoringProgress && nextPage > maxAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pdfController.jumpToPage(_maxReachedPage);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sahifalarni ketma-ket o'qing. Juda uzoqqa sakrash bloklandi."),
            duration: Duration(seconds: 2),
          ),
        );
      });
      return;
    }
    _lastPage = nextPage;
    if (_lastPage > _maxReachedPage) {
      _maxReachedPage = _lastPage;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      final shouldSaveByStep = (_lastPage - _lastSavedPage) >= _saveEveryPages;
      if (shouldSaveByStep) {
        unawaited(_saveProgress(_lastPage));
      }
    });
  }

  Future<void> _saveProgress(int pageNo) async {
    if (_userId.isEmpty || _totalPages <= 0 || _restoringProgress || _isSaving) return;
    if (pageNo <= _lastSavedPage) return;
    _isSaving = true;
    try {
      final percent = ((pageNo / _totalPages) * 100).clamp(0, 100).toDouble();
      await ref.read(booksRepositoryProvider).upsertProgress(
            userId: _userId,
            bookId: widget.bookId,
            pageNo: pageNo,
            progressPercent: percent,
          );
      _lastSavedPage = pageNo;
      ref.invalidate(bookProgressProvider);
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _flushProgressNow() async {
    if (!mounted) return;
    await _saveProgress(_lastPage);
  }

  Future<void> _protectScreen() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }

  Future<void> _clearScreenProtection() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }
}
