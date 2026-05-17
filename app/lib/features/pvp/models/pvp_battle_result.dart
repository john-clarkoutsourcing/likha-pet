import 'package:flutter/material.dart';

/// Represents the validation status of a completed PvP battle
enum ValidationStatus {
  pending,    // Still validating
  accepted,   // Battle approved, MMR awarded
  rejected,   // Battle failed validation, no MMR
  suspicious, // Flagged for review but accepted (with MMR)
}

/// Complete battle result with validation details
class PvpBattleResult {
  final bool isWin;
  final bool isDraw;
  final bool isLoss;
  final String opponentName;
  final String? opponentId;
  
  // Validation status
  final ValidationStatus validationStatus;
  final String? validationReason;
  final bool flaggedForReview;
  final int mmrChange;
  
  // Battle summary
  final int battleDurationMs;
  final int finalPlayerHp;
  final int finalOpponentHp;

  const PvpBattleResult({
    required this.isWin,
    required this.isDraw,
    required this.isLoss,
    required this.opponentName,
    this.opponentId,
    required this.validationStatus,
    this.validationReason,
    this.flaggedForReview = false,
    required this.mmrChange,
    required this.battleDurationMs,
    required this.finalPlayerHp,
    required this.finalOpponentHp,
  });

  /// Friendly display text for the validation status
  String get validationStatusText {
    switch (validationStatus) {
      case ValidationStatus.pending:
        return 'Validating...';
      case ValidationStatus.accepted:
        return 'Battle Approved ✓';
      case ValidationStatus.rejected:
        return 'Battle Rejected ✗';
      case ValidationStatus.suspicious:
        return 'Under Review';
    }
  }

  /// Color for validation status badge
  Color get validationStatusColor {
    switch (validationStatus) {
      case ValidationStatus.pending:
        return Colors.amber;
      case ValidationStatus.accepted:
        return const Color(0xFF4CAF50);
      case ValidationStatus.rejected:
        return Colors.redAccent;
      case ValidationStatus.suspicious:
        return Colors.orange;
    }
  }

  /// Icon for validation status
  IconData get validationStatusIcon {
    switch (validationStatus) {
      case ValidationStatus.pending:
        return Icons.hourglass_empty;
      case ValidationStatus.accepted:
        return Icons.check_circle;
      case ValidationStatus.rejected:
        return Icons.cancel;
      case ValidationStatus.suspicious:
        return Icons.warning;
    }
  }

  /// Whether the player should receive MMR for this battle
  bool get mmrtAwarded {
    return validationStatus == ValidationStatus.accepted ||
        validationStatus == ValidationStatus.suspicious;
  }

  /// Helpful message for the player
  String get helpMessage {
    if (validationStatus == ValidationStatus.rejected) {
      return 'This battle did not pass validation and was rejected. No MMR awarded. '
          'If you believe this is a mistake, contact support.';
    } else if (validationStatus == ValidationStatus.suspicious) {
      return 'This battle passed validation but has been flagged for review. '
          'MMR was awarded, but the account is being monitored.';
    } else if (validationStatus == ValidationStatus.pending) {
      return 'Your battle is being validated by the server. '
          'This usually takes a few seconds...';
    } else {
      return 'Battle validation complete. Well played!';
    }
  }
}
