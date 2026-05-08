import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

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
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ?? const [];
    final match = assets.where((e) => e.id == widget.assetId);
    final asset = match.isEmpty ? null : match.first;
    if (asset == null) return const Scaffold(body: Center(child: Text("Fayl topilmadi")));

    if (asset.fileType == 'ppt') {
      return Scaffold(
        appBar: AppBar(title: Text(asset.title)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(asset.fileUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
              await _saveProgress();
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('PPT ni ochish'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(asset.title)),
      body: SfPdfViewer.network(
        asset.fileUrl,
        onDocumentLoaded: (details) => _totalPages = details.document.pages.count,
        onPageChanged: (details) {
          _lastPage = details.newPageNumber;
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 2), _saveProgress);
        },
      ),
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
