import 'package:flutter/material.dart';

import '../../domain/analysis_models.dart';
import '../theme/vivy_colors.dart';
import '../theme/vivy_spacing.dart';
import '../theme/vivy_text_styles.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VivyColors.appBackground,
      appBar: AppBar(
        title: const Text('Check History'),
        backgroundColor: Colors.transparent,
        foregroundColor: VivyColors.textPrimary,
        elevation: 0,
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('No local history yet.', style: VivyTextStyles.body),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(VivySpacing.pagePadding),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = entries[index];
                final confidenceText = item.confidence == null
                    ? 'N/A'
                    : '${(item.confidence! * 100).toStringAsFixed(1)}%';

                final isFraud = item.label.toLowerCase() == 'fraudulent';
                final accent = isFraud ? VivyColors.danger : VivyColors.success;
                final soft = isFraud
                    ? VivyColors.dangerSoft
                    : VivyColors.successSoft;

                return Container(
                  decoration: BoxDecoration(
                    color: VivyColors.surface,
                    borderRadius: BorderRadius.circular(
                      VivySpacing.radiusMedium,
                    ),
                    border: Border.all(color: VivyColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(VivySpacing.radiusMedium),
                            topRight: Radius.circular(VivySpacing.radiusMedium),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              color: accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: VivyColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confidence: $confidenceText',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: VivyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Timestamp: ${item.timestamp.toLocal()}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: VivyColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
