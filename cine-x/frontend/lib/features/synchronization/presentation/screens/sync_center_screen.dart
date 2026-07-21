import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SyncProvider>().refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final user = context.watch<AuthProvider>().user;
    final summary = sync.summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm đồng bộ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: sync.loading ? null : sync.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sync.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _ModeBanner(userName: user?.displayName),
            const SizedBox(height: 16),
            if (sync.error != null) ...[
              _ErrorBanner(message: sync.error!),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final cards = [
                  _CountCard(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Chờ tạo',
                    value: summary.pendingCreates,
                    accent: CineXPalette.primary,
                  ),
                  _CountCard(
                    icon: Icons.edit_note_rounded,
                    label: 'Chờ cập nhật',
                    value: summary.pendingUpdates,
                    accent: CineXPalette.secondary,
                  ),
                  _CountCard(
                    icon: Icons.delete_outline_rounded,
                    label: 'Chờ xóa',
                    value: summary.pendingDeletes,
                    accent: CineXPalette.warning,
                  ),
                  _CountCard(
                    icon: Icons.upload_file_rounded,
                    label: 'Chờ tải lên',
                    value: summary.pendingUploads,
                    accent: CineXPalette.accent,
                  ),
                  _CountCard(
                    icon: Icons.error_outline_rounded,
                    label: 'Thất bại',
                    value: summary.failed,
                    accent: Theme.of(context).colorScheme.error,
                  ),
                  _CountCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Xung đột',
                    value: summary.conflicts,
                    accent: CineXPalette.warning,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      for (final card in cards) ...[
                        card,
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                }
                return GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: cards,
                );
              },
            ),
            const SizedBox(height: 18),
            _LastSync(summary: summary),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: sync.loading ? null : sync.syncNow,
                  icon: sync.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(sync.loading ? 'Đang đồng bộ' : 'Đồng bộ ngay'),
                ),
                OutlinedButton.icon(
                  onPressed: sync.loading || summary.failed == 0
                      ? null
                      : sync.syncNow,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Thử lại lỗi'),
                ),
                OutlinedButton.icon(
                  onPressed: summary.conflicts == 0 ? null : () {},
                  icon: const Icon(Icons.rule_rounded),
                  label: const Text('Giải quyết xung đột'),
                ),
                OutlinedButton.icon(
                  onPressed: sync.loading ? null : sync.syncNow,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Tải dự án cục bộ lên'),
                ),
                OutlinedButton.icon(
                  onPressed: sync.loading ? null : sync.syncNow,
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text('Tải dữ liệu đám mây'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(210),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_sync_rounded, color: CineXPalette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userName == null
                    ? 'Ngoại tuyến - dữ liệu chỉ lưu trên thiết bị'
                    : 'Tài khoản: $userName',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastSync extends StatelessWidget {
  const _LastSync({required this.summary});

  final SyncSummary summary;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d/M/y HH:mm', 'vi_VN');
    final text = summary.lastSyncedAt == null
        ? 'Lần đồng bộ cuối: chưa có'
        : 'Lần đồng bộ cuối: ${formatter.format(summary.lastSyncedAt!)}';
    return Text(
      summary.lastError == null ? text : '$text\nLỗi gần nhất: ${summary.lastError}',
      style: const TextStyle(color: CineXPalette.textSecondary),
    );
  }
}
