import 'package:flutter/material.dart';

class TranscriptionProgressBanner extends StatelessWidget {
  final int activeCount;

  const TranscriptionProgressBanner({super.key, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = activeCount > 1
        ? '텍스트 변환을 $activeCount개 진행 중이에요.'
        : '텍스트 변환 중이에요.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '완료되면 바로 결과 화면으로 안내할게요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
