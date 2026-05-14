import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class StagePreviewScreen extends StatelessWidget {
  final String stageId;
  const StagePreviewScreen({super.key, required this.stageId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Stage $stageId',
            style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Stage preview — Phase 3',
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
