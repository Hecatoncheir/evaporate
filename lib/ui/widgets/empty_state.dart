import 'package:flutter/material.dart';

import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EvaporateSpacing.vast),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: EvaporateIconSize.hero,
              color: context.colors.accent,
            ),
            const SizedBox(height: EvaporateSpacing.panel),
            Text(title, textAlign: TextAlign.center, style: context.text.title),
            if (description != null) ...[
              const SizedBox(height: EvaporateSpacing.gap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: context.text.prose.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: EvaporateSpacing.section),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
