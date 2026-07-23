import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoadingView extends StatefulWidget {
  const LoadingView({super.key, this.message = 'Đang tải không gian làm việc'});

  final String message;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final opacity = 0.45 + (_controller.value * 0.35);
                  return Opacity(opacity: opacity, child: child);
                },
                child: const _SkeletonPoster(),
              ),
              const SizedBox(height: 22),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message = 'Hãy bắt đầu tạo phần đầu tiên cho kế hoạch sản xuất.',
    this.action,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      icon: icon,
      iconColor: CineXPalette.accent,
      title: title,
      message: message,
      action: action,
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      icon: Icons.error_outline_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Có mục cần kiểm tra',
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
    );
  }
}

class _StateShell extends StatelessWidget {
  const _StateShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CineXPalette.card.withAlpha(230),
              border: Border.all(color: CineXPalette.divider),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: CineXPalette.primary.withAlpha(24),
                  blurRadius: 40,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IllustrationBadge(icon: icon, color: iconColor),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: CineXPalette.textSecondary,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  const _IllustrationBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(95),
            CineXPalette.primary.withAlpha(65),
            CineXPalette.surface,
          ],
        ),
        border: Border.all(color: color.withAlpha(105)),
      ),
      child: Icon(icon, size: 42, color: CineXPalette.textPrimary),
    );
  }
}

class _SkeletonPoster extends StatelessWidget {
  const _SkeletonPoster();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CineXPalette.surface,
            CineXPalette.card,
            Color(0xFF302B63),
          ],
        ),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: CineXPalette.textPrimary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                color: CineXPalette.textPrimary,
              ),
            ),
            const Spacer(),
            const _SkeletonLine(width: 180),
            const SizedBox(height: 10),
            const _SkeletonLine(width: 120),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: CineXPalette.textPrimary.withAlpha(22),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
