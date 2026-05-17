import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/battle_action_log.dart';
import '../services/pvp_validation_service.dart';
import '../widgets/validation_toast.dart';

/// Helper class to manage validation flow in PvP battle screens
class PvpValidationHelper {
  static Future<BattleValidationResponse?> submitAndShowValidation({
    required BuildContext context,
    required BattleValidationRequest request,
    required PvpValidationService service,
  }) async {
    // Show validating toast
    ValidationToastManager.show(
      context,
      message: 'Validating your battle...',
      type: ValidationToastType.validating,
    );

    try {
      final response = await service.submitBattleValidation(request);

      // Update toast based on result
      if (response.isAccepted) {
        ValidationToastManager.show(
          context,
          message: 'Battle approved! +${response.mmrChange ?? 0} MMR',
          type: ValidationToastType.success,
          duration: const Duration(seconds: 4),
        );
      } else if (response.isSuspicious) {
        ValidationToastManager.show(
          context,
          message: 'Battle flagged for review',
          type: ValidationToastType.warning,
          duration: const Duration(seconds: 4),
        );
      } else if (response.isRejected) {
        ValidationToastManager.show(
          context,
          message: 'Battle validation failed: ${response.reason}',
          type: ValidationToastType.error,
          duration: const Duration(seconds: 4),
        );
      }

      return response;
    } catch (e) {
      ValidationToastManager.show(
        context,
        message: 'Validation error: $e',
        type: ValidationToastType.error,
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }

  /// Build validation status widget for display in result screen
  static Widget buildValidationStatusWidget(BattleValidationResponse response) {
    final isAccepted = response.isAccepted;
    final isSuspicious = response.isSuspicious;
    final isRejected = response.isRejected;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isAccepted) {
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle;
      statusText = 'Battle Approved ✓';
    } else if (isSuspicious) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Under Review';
    } else {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
      statusText = 'Battle Rejected ✗';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (response.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    response.reason!,
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
