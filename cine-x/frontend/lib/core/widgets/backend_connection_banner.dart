import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../network/backend_connection_provider.dart';
import '../theme/app_theme.dart';

class BackendConnectionBanner extends StatefulWidget {
  const BackendConnectionBanner({super.key});

  @override
  State<BackendConnectionBanner> createState() =>
      _BackendConnectionBannerState();
}

class _BackendConnectionBannerState extends State<BackendConnectionBanner> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connection = context.read<BackendConnectionProvider>();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => connection.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<BackendConnectionProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, label, foreground, background) = switch (connection.status) {
      BackendConnectionStatus.online => (
          Icons.cloud_done_rounded,
          'Studio server online',
          CineXPalette.success,
          CineXPalette.success.withAlpha(24),
        ),
      BackendConnectionStatus.offline => (
          Icons.cloud_off_rounded,
          connection.error ?? 'Unable to connect to the server',
          colors.error,
          colors.error.withAlpha(24),
        ),
      BackendConnectionStatus.checking => (
          Icons.sync_rounded,
          'Checking studio server',
          CineXPalette.accent,
          CineXPalette.accent.withAlpha(24),
        ),
      BackendConnectionStatus.idle => (
          Icons.cloud_queue_rounded,
          'Server status not checked',
          CineXPalette.textSecondary,
          CineXPalette.surface.withAlpha(160),
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground.withAlpha(80)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: foreground.withAlpha(18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: CineXPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Recheck server',
              onPressed: connection.checking ? null : connection.check,
              icon: connection.checking
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
