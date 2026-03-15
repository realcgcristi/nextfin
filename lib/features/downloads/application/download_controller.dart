import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/providers.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/server_account.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

class DownloadEntry {
  const DownloadEntry({
    required this.itemId,
    required this.title,
    required this.type,
    required this.path,
    required this.status,
    required this.progress,
  });

  final String itemId;
  final String title;
  final String type;
  final String path;
  final String status;
  final double progress;

  bool get isDone => status == 'done' && File(path).existsSync();
  bool get canRetry => status == 'failed';

  DownloadEntry copyWith({
    String? itemId,
    String? title,
    String? type,
    String? path,
    String? status,
    double? progress,
  }) {
    return DownloadEntry(
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      type: type ?? this.type,
      path: path ?? this.path,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'title': title,
    'type': type,
    'path': path,
    'status': status,
    'progress': progress,
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    itemId: json['itemId']?.toString() ?? '',
    title: json['title']?.toString() ?? 'download',
    type: json['type']?.toString() ?? 'Item',
    path: json['path']?.toString() ?? '',
    status: json['status']?.toString() ?? 'queued',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
  );
}

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, List<DownloadEntry>>(
      (Ref ref) => DownloadController(ref),
    );

class DownloadController extends StateNotifier<List<DownloadEntry>> {
  DownloadController(this._ref)
      : super(
          _ref
              .read(appStorageProvider)
              .loadDownloads()
              .map(DownloadEntry.fromJson)
              .toList(),
        ) {
    _reconcile();
  }

  final Ref _ref;

  Future<void> queue(MediaItem item) async {
    final acc = _ref.read(activeAccountProvider);
    if (acc == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${dir.path}/nextfin-downloads');
    if (!dlDir.existsSync()) dlDir.createSync(recursive: true);
    final ext = item.type == 'Episode' || item.type == 'Movie' ? '.mp4' : '.bin';
    final safe = item.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final path = '${dlDir.path}/${item.id}_$safe$ext';
    final existing = state.where((e) => e.itemId == item.id).firstOrNull;
    if (existing?.status == 'downloading') return;
    final entry =
        existing?.copyWith(path: path, status: 'queued', progress: 0) ??
        DownloadEntry(
          itemId: item.id,
          title: item.name,
          type: item.type,
          path: path,
          status: 'queued',
          progress: 0,
        );
    _upsert(entry);
    await _download(acc, entry);
  }

  Future<void> retry(String itemId) async {
    final entry = state.where((e) => e.itemId == itemId).firstOrNull;
    final acc = _ref.read(activeAccountProvider);
    if (entry == null || acc == null) return;
    await _download(acc, entry.copyWith(status: 'queued', progress: 0));
  }

  Future<void> _download(ServerAccount acc, DownloadEntry entry) async {
    final api = _ref.read(jellyfinApiProvider);
    final dio = Dio();
    _upsert(entry.copyWith(status: 'downloading', progress: 0));
    try {
      final info = await api.getPlaybackInfo(acc, entry.itemId);
      final cand =
          api
              .playbackCandidates(
                acc,
                entry.itemId,
                playbackInfo: info,
              )
              .where((item) => !item.isLive && !item.isHls)
              .firstOrNull;
      if (cand == null) {
        throw Exception('No downloadable source was returned for this item.');
      }
      final response = await dio.download(
        cand.url,
        entry.path,
        options: Options(
          headers: <String, String>{
            ...api.playerHeaders(acc),
            ...cand.headers,
          },
          validateStatus: (code) => code != null && code < 500,
        ),
        onReceiveProgress: (count, total) {
          if (total <= 0) return;
          _upsert(
            entry.copyWith(
              status: 'downloading',
              progress: (count / total).clamp(0.0, 1.0),
            ),
          );
        },
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw Exception('The server returned HTTP $status for this download.');
      }
      final file = File(entry.path);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('The downloaded file was empty.');
      }
      _upsert(entry.copyWith(status: 'done', progress: 1));
    } catch (_) {
      final file = File(entry.path);
      if (file.existsSync()) {
        await file.delete();
      }
      _upsert(entry.copyWith(status: 'failed', progress: 0));
    }
  }

  Future<void> remove(String itemId) async {
    final target = state.where((e) => e.itemId == itemId).firstOrNull;
    if (target != null && target.path.isNotEmpty) {
      final file = File(target.path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    state = state.where((e) => e.itemId != itemId).toList();
    await _persist();
  }

  void _upsert(DownloadEntry entry) {
    final list = [...state.where((e) => e.itemId != entry.itemId), entry];
    state = list;
    _persist();
  }

  Future<void> _reconcile() async {
    final fixed =
        state.map((item) {
          final exists = item.path.isNotEmpty && File(item.path).existsSync();
          if (item.status == 'done' && exists) return item;
          if (!exists && item.status == 'done') {
            return item.copyWith(status: 'failed', progress: 0);
          }
          if (item.status == 'queued' || item.status == 'downloading') {
            return item.copyWith(status: exists ? 'failed' : 'failed', progress: 0);
          }
          return item;
        }).toList();
    state = fixed;
    await _persist();
  }

  Future<void> _persist() async {
    await _ref
        .read(appStorageProvider)
        .saveDownloads(state.map((e) => e.toJson()).toList());
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
