import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/screen_protection.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/media_url_resolver.dart';
import '../../../../core/services/lesson_slides_bytes_cache.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/lesson_assets_state.dart';

class AssetViewPage extends ConsumerStatefulWidget {
  const AssetViewPage({
    super.key,
    required this.lessonId,
    required this.assetId,
  });

  final String lessonId;
  final String assetId;

  @override
  ConsumerState<AssetViewPage> createState() => _AssetViewPageState();
}

class _AssetViewPageState extends ConsumerState<AssetViewPage> {
  int _totalPages = 0;
  int _lastPage = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenProtection.enable());
  }

  @override
  void dispose() {
    unawaited(ScreenProtection.disable());
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ?? const [];
    final match = assets.where((e) => e.id == widget.assetId);
    final asset = match.isEmpty ? null : match.first;
    if (asset == null) return const Scaffold(body: Center(child: Text("Fayl topilmadi")));

    final isPpt = asset.fileType.toLowerCase().startsWith('ppt');
    if (isPpt) {
      final isDataUrl = asset.fileUrl.trim().startsWith('data:');
      return Scaffold(
        appBar: AppBar(title: Text(asset.title)),
        body: Center(
          child: isDataUrl
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "PPT data-url formatida saqlangan. Tashqi viewerda ochish uchun Supabase bucket sozlang va fayl public URL bilan saqlansin.",
                    textAlign: TextAlign.center,
                  ),
                )
              : FilledButton.icon(
                  onPressed: () async {
                    final resolved = MediaUrlResolver.resolveFetchUrl(
                      asset.fileUrl,
                      apiBaseUrl: getApiBaseUrl(),
                    );
                    final uri = Uri.tryParse(resolved);
                    if (uri == null) return;
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
                    await _saveProgress();
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('PPT ni ochish'),
                ),
        ),
      );
    }

    final isPdfDataUrl = asset.fileUrl.trim().startsWith('data:application/pdf');
    return Scaffold(
      appBar: AppBar(title: Text(asset.title)),
      body: isPdfDataUrl ? _buildPdfMemory(asset.fileUrl) : _buildPdfNetwork(asset.fileUrl),
    );
  }

  Widget _buildPdfMemory(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma <= 0) return const Center(child: Text("PDF formati noto'g'ri."));
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
      return _buildPdfViewer(bytes);
    } catch (_) {
      return const Center(child: Text("PDF ni o'qib bo'lmadi."));
    }
  }

  Widget _buildPdfViewer(Uint8List bytes) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SfPdfViewer.memory(
          bytes,
          onDocumentLoaded: (details) {
            setState(() => _totalPages = details.document.pages.count);
          },
          onPageChanged: (details) {
            setState(() => _lastPage = details.newPageNumber);
            _debounce?.cancel();
            _debounce = Timer(const Duration(seconds: 2), _saveProgress);
          },
        ),
        if (_totalPages > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(child: _pageCounterChip()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pageCounterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$_lastPage / $_totalPages',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPdfNetwork(String url) {
    return FutureBuilder<Uint8List>(
      future: _downloadPdfBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                snapshot.error is Exception ? (snapshot.error as Exception).toString().replaceFirst('Exception: ', '') : "PDF yuklanmadi.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _buildPdfViewer(snapshot.data!);
      },
    );
  }

  Future<Uint8List> _downloadPdfBytes(String url) {
    return LessonSlidesBytesCache.loadBytes(
      url,
      apiBaseUrl: getApiBaseUrl(),
      fetcher: (normalized) async {
        try {
          return await LessonSlidesBytesCache.fetchPdfBytes(normalized);
        } on Exception catch (e) {
          final msg = e.toString();
          if (msg.contains('bucket not found')) {
            throw Exception(
              "Storage bucket topilmadi. Admin panelda `content-assets` bucketni yarating.",
            );
          }
          rethrow;
        }
      },
    );
  }

  Future<void> _saveProgress() async {
    final userId = ref.read(authControllerProvider).userId ?? '';
    if (userId.isEmpty) return;
    final progress = _totalPages > 0 ? ((_lastPage / _totalPages) * 100).clamp(0, 100).toDouble() : 0.0;
    await ref.read(lessonAssetsRepositoryProvider).upsertProgress(
          userId: userId,
          assetId: widget.assetId,
          pageNo: _lastPage,
          progressPercent: progress,
        );
  }
}
