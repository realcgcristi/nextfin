import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder:
          (BuildContext context, int index) => Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            highlightColor: Theme.of(context).colorScheme.surfaceContainer,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
    );
  }
}
