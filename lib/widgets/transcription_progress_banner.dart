import 'package:flutter/material.dart';

class TranscriptionProgressBanner extends StatelessWidget {
  final int activeCount;
  final double? progress;
  final int? currentChunk;
  final int? totalChunks;

  const TranscriptionProgressBanner({
    super.key,
    required this.activeCount,
    this.progress,
    this.currentChunk,
    this.totalChunks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = activeCount > 1
        ? '텍스트 변환을 $activeCount개 진행 중이에요.'
        : '텍스트 변환 중이에요.';
    
    final progressText = totalChunks != null && currentChunk != null
        ? '$currentChunk / $totalChunks 청크 처리 중'
        : '완료되면 바로 결과 화면으로 안내할게요.';
    
    final progressPercentage = progress != null
        ? '${(progress! * 100).toStringAsFixed(0)}%'
        : null;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (progressPercentage != null)
                Text(
                  progressPercentage,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progressText,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          progress != null
              ? LinearProgressIndicator(value: progress)
              : const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
