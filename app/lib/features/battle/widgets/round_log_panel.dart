import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RoundLogPanel extends StatefulWidget {
  final String log;

  const RoundLogPanel({super.key, required this.log});

  @override
  State<RoundLogPanel> createState() => _RoundLogPanelState();
}

class _RoundLogPanelState extends State<RoundLogPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(RoundLogPanel old) {
    super.didUpdateWidget(old);
    // Scroll to bottom when log updates
    if (widget.log != old.log) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(10),
        child: Text(
          widget.log,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
