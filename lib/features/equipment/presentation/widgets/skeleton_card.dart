import 'package:flutter/material.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceVariant;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 120, color: baseColor),
            const SizedBox(height: 8),
            Container(height: 12, width: 200, color: baseColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Container(height: 10, color: baseColor)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 10, color: baseColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}