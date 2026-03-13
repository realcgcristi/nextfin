import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading:
          () => loading ?? const Center(child: CircularProgressIndicator()),
      error:
          (Object error, StackTrace _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }
}
