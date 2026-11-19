import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Stacks [children] with even vertical gaps. Skips nulls.
class FormGap extends StatelessWidget {
  final List<Widget?> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const FormGap({
    super.key,
    required this.children,
    this.gap = AppSpacing.lg,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final visible = [for (final child in children) ?child];
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          visible[i],
        ],
      ],
    );
  }
}
