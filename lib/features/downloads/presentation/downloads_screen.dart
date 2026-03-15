import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/download_controller.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(downloadControllerProvider).reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('downloads')),
      body: items.isEmpty
          ? const Center(child: Text('nothing downloaded yet'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int idx) {
                final item = items[idx];
                return Card(
                  child: ListTile(
                    onTap: item.isDone
                        ? () => context.push(
                              '/player/${item.itemId}?title=${Uri.encodeComponent(item.title)}&filePath=${Uri.encodeComponent(item.path)}',
                            )
                        : null,
                    leading: Icon(
                      switch (item.status) {
                        'done' => Icons.download_done_rounded,
                        'downloading' => Icons.downloading_rounded,
                        'failed' => Icons.error_outline_rounded,
                        _ => Icons.download_rounded,
                      },
                    ),
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          item.status == 'downloading'
                              ? '${(item.progress * 100).round()}% downloaded'
                              : item.status == 'done'
                                  ? 'saved offline'
                                  : item.status == 'failed'
                                      ? 'download failed'
                                      : item.status,
                        ),
                        if (item.status == 'downloading') ...<Widget>[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: item.progress),
                        ],
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        if (item.canRetry)
                          IconButton(
                            onPressed: () => ref
                                .read(downloadControllerProvider.notifier)
                                .retry(item.itemId),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        IconButton(
                          onPressed: () => ref
                              .read(downloadControllerProvider.notifier)
                              .remove(item.itemId),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
