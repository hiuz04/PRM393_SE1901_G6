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
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.pendingCreate,
                    ),
                  ),
                  _CountCard(
                    icon: Icons.edit_note_rounded,
                    label: 'Chờ cập nhật',
                    value: summary.pendingUpdates,
                    accent: CineXPalette.secondary,
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.pendingUpdate,
                    ),
                  ),
                  _CountCard(
                    icon: Icons.delete_outline_rounded,
                    label: 'Chờ xóa',
                    value: summary.pendingDeletes,
                    accent: CineXPalette.warning,
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.pendingDelete,
                    ),
                  ),
                  _CountCard(
                    icon: Icons.upload_file_rounded,
                    label: 'Chờ tải lên',
                    value: summary.pendingUploads,
                    accent: CineXPalette.accent,
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.pendingUpload,
                    ),
                  ),
                  _CountCard(
                    icon: Icons.error_outline_rounded,
                    label: 'Thất bại',
                    value: summary.failed,
                    accent: Theme.of(context).colorScheme.error,
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.failed,
                    ),
                  ),
                  _CountCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Xung đột',
                    value: summary.conflicts,
                    accent: CineXPalette.warning,
                    onTap: () => _showSyncDetails(
                      context,
                      SyncDetailKind.conflicts,
                    ),
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
                  onPressed: sync.loading
                      ? null
                      : () => _chooseProjectAndSync(context),
                  icon: sync.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    sync.loading ? 'Đang đồng bộ' : 'Chọn project để đồng bộ',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: sync.loading || summary.failed == 0
                      ? null
                      : () => _chooseProjectAndSync(context),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Thử lại lỗi'),
                ),
                OutlinedButton.icon(
                  onPressed: summary.conflicts == 0
                      ? null
                      : () => _showSyncDetails(
                            context,
                            SyncDetailKind.conflicts,
                          ),
                  icon: const Icon(Icons.rule_rounded),
                  label: const Text('Giải quyết xung đột'),
                ),
                OutlinedButton.icon(
                  onPressed: sync.loading
                      ? null
                      : () => _chooseProjectAndSync(context),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Tải dự án cục bộ lên'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSyncDetails(
  BuildContext context,
  SyncDetailKind kind,
) async {
  final sync = context.read<SyncProvider>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: sync,
      child: _SyncDetailSheet(kind: kind),
    ),
  );
}

Future<void> _chooseProjectAndSync(BuildContext context) async {
  final sync = context.read<SyncProvider>();
  final project = await showModalBottomSheet<SyncProjectOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: sync,
      child: const _ProjectUploadSheet(),
    ),
  );
  if (project == null || !context.mounted) return;
  final ok = await sync.syncProject(project.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Đã đồng bộ "${project.title}" lên server'
            : sync.error ?? 'Không thể đồng bộ project này',
      ),
    ),
  );
}

class _ProjectUploadSheet extends StatefulWidget {
  const _ProjectUploadSheet();

  @override
  State<_ProjectUploadSheet> createState() => _ProjectUploadSheetState();
}

class _ProjectUploadSheetState extends State<_ProjectUploadSheet> {
  late Future<List<SyncProjectOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SyncProvider>().localProjects();
  }

  void _reload() {
    setState(() {
      _future = context.read<SyncProvider>().localProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.74,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: CineXPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_upload_rounded,
                    color: CineXPalette.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn project local',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: CineXPalette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Project được chọn sẽ được đẩy từ SQLite lên DB server.',
                          style: TextStyle(color: CineXPalette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: CineXPalette.divider),
            Expanded(
              child: FutureBuilder<List<SyncProjectOption>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _DetailEmpty(
                      icon: Icons.error_outline_rounded,
                      message: snapshot.error.toString(),
                    );
                  }
                  final projects = snapshot.data ?? const [];
                  if (projects.isEmpty) {
                    return const _DetailEmpty(
                      icon: Icons.movie_creation_rounded,
                      message: 'SQLite chưa có project local để đồng bộ.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ProjectUploadTile(
                      project: projects[index],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectUploadTile extends StatelessWidget {
  const _ProjectUploadTile({required this.project});

  final SyncProjectOption project;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d/M/y HH:mm', 'vi_VN');
    final updatedAt =
        project.updatedAt == null ? null : formatter.format(project.updatedAt!);
    return Material(
      color: CineXPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CineXPalette.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pop(context, project),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: CineXPalette.primary.withAlpha(36),
                foregroundColor: CineXPalette.textPrimary,
                child: const Icon(Icons.movie_creation_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (project.genre != null) project.genre!,
                        '${project.supportedItemCount} mục có thể upload',
                        if (updatedAt != null) 'Sửa lúc $updatedAt',
                      ].join(' · '),
                      style: const TextStyle(
                        color: CineXPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailChip(
                          label: project.uploaded
                              ? 'Đã có trên server'
                              : 'Chưa upload',
                        ),
                        if (project.pendingCount > 0)
                          _DetailChip(
                              label: '${project.pendingCount} đang chờ'),
                        if (project.failedCount > 0)
                          _DetailChip(label: '${project.failedCount} lỗi'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CineXPalette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CineXPalette.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withAlpha(180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncDetailSheet extends StatefulWidget {
  const _SyncDetailSheet({required this.kind});

  final SyncDetailKind kind;

  @override
  State<_SyncDetailSheet> createState() => _SyncDetailSheetState();
}

class _SyncDetailSheetState extends State<_SyncDetailSheet> {
  late Future<List<SyncDetailItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SyncProvider>().details(widget.kind);
  }

  void _reload() {
    setState(() {
      _future = context.read<SyncProvider>().details(widget.kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = _detailSpec(context, widget.kind);
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: CineXPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Icon(spec.icon, color: spec.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: CineXPalette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          spec.description,
                          style: const TextStyle(
                            color: CineXPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: CineXPalette.divider),
            Expanded(
              child: FutureBuilder<List<SyncDetailItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _DetailEmpty(
                      icon: Icons.error_outline_rounded,
                      message: snapshot.error.toString(),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return _DetailEmpty(
                      icon: spec.icon,
                      message: spec.emptyMessage,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SyncDetailTile(
                      item: items[index],
                      accent: spec.accent,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncDetailTile extends StatelessWidget {
  const _SyncDetailTile({
    required this.item,
    required this.accent,
  });

  final SyncDetailItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d/M/y HH:mm', 'vi_VN');
    final time = item.updatedAt ?? item.createdAt;
    final meta = [
      _entityLabel(item.entityType),
      _operationLabel(item.operation),
      if (item.retryCount > 0) 'Đã thử ${item.retryCount} lần',
      if (time != null) formatter.format(time),
    ].join(' · ');
    final error = item.error?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_entityIcon(item.entityType), color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: CineXPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(label: 'ID: ${_shortId(item.entityId)}'),
                if (item.projectId != null)
                  _DetailChip(label: 'Project: ${item.projectId}'),
                if (item.conflictingFields.isNotEmpty)
                  _DetailChip(
                    label: 'Trường: ${item.conflictingFields.join(', ')}',
                  ),
              ],
            ),
            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailError(message: _friendlySyncError(error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: CineXPalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withAlpha(72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailEmpty extends StatelessWidget {
  const _DetailEmpty({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: CineXPalette.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CineXPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
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
      summary.lastError == null
          ? text
          : '$text\nLỗi gần nhất: ${summary.lastError}',
      style: const TextStyle(color: CineXPalette.textSecondary),
    );
  }
}

class _DetailSpec {
  const _DetailSpec({
    required this.title,
    required this.description,
    required this.emptyMessage,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String description;
  final String emptyMessage;
  final IconData icon;
  final Color accent;
}

_DetailSpec _detailSpec(BuildContext context, SyncDetailKind kind) {
  return switch (kind) {
    SyncDetailKind.pendingCreate => const _DetailSpec(
        title: 'Đang chờ tạo',
        description: 'Dữ liệu mới trên thiết bị chưa được gửi lên server.',
        emptyMessage: 'Không có dữ liệu nào đang chờ tạo.',
        icon: Icons.add_circle_outline_rounded,
        accent: CineXPalette.primary,
      ),
    SyncDetailKind.pendingUpdate => const _DetailSpec(
        title: 'Đang chờ cập nhật',
        description: 'Dữ liệu đã sửa trên thiết bị chưa được gửi lên server.',
        emptyMessage: 'Không có dữ liệu nào đang chờ cập nhật.',
        icon: Icons.edit_note_rounded,
        accent: CineXPalette.secondary,
      ),
    SyncDetailKind.pendingDelete => const _DetailSpec(
        title: 'Đang chờ xóa',
        description: 'Lệnh xóa trên thiết bị chưa được gửi lên server.',
        emptyMessage: 'Không có lệnh xóa nào đang chờ.',
        icon: Icons.delete_outline_rounded,
        accent: CineXPalette.warning,
      ),
    SyncDetailKind.pendingUpload => const _DetailSpec(
        title: 'Đang chờ tải lên',
        description: 'Tệp hoặc media chưa được upload lên server.',
        emptyMessage: 'Không có tệp nào đang chờ tải lên.',
        icon: Icons.upload_file_rounded,
        accent: CineXPalette.accent,
      ),
    SyncDetailKind.failed => _DetailSpec(
        title: 'Đồng bộ thất bại',
        description:
            'Các thao tác đã thử gửi nhưng bị server hoặc mạng từ chối.',
        emptyMessage: 'Không có thao tác đồng bộ bị lỗi.',
        icon: Icons.error_outline_rounded,
        accent: Theme.of(context).colorScheme.error,
      ),
    SyncDetailKind.conflicts => const _DetailSpec(
        title: 'Xung đột dữ liệu',
        description: 'Dữ liệu local và server cùng thay đổi trên một mục.',
        emptyMessage: 'Không có xung đột nào cần xử lý.',
        icon: Icons.warning_amber_rounded,
        accent: CineXPalette.warning,
      ),
  };
}

String _entityLabel(String entityType) {
  return switch (entityType) {
    'PROJECT' => 'Dự án',
    'PROJECT_MEMBER' => 'Thành viên',
    'ACT' => 'Hồi',
    'CHARACTER' => 'Nhân vật',
    'STORY_LOCATION' => 'Bối cảnh',
    'SHOOTING_LOCATION' => 'Địa điểm quay',
    'FILM_RESOURCE' => 'Tài nguyên',
    'SCENE' => 'Cảnh',
    'SHOOTING_DAY' => 'Ngày quay',
    'FILE_ASSET' => 'Tệp',
    _ => entityType,
  };
}

String _operationLabel(String operation) {
  return switch (operation) {
    'CREATE' => 'Tạo mới',
    'UPDATE' => 'Cập nhật',
    'DELETE' => 'Xóa',
    'UPLOAD_FILE' => 'Tải tệp',
    'CONFLICT' => 'Xung đột',
    _ => operation,
  };
}

IconData _entityIcon(String entityType) {
  return switch (entityType) {
    'PROJECT' => Icons.movie_creation_rounded,
    'PROJECT_MEMBER' => Icons.manage_accounts_rounded,
    'ACT' => Icons.view_agenda_rounded,
    'CHARACTER' => Icons.person_rounded,
    'STORY_LOCATION' => Icons.place_rounded,
    'SHOOTING_LOCATION' => Icons.location_city_rounded,
    'FILM_RESOURCE' => Icons.inventory_2_rounded,
    'SCENE' => Icons.movie_filter_rounded,
    'SHOOTING_DAY' => Icons.event_available_rounded,
    'FILE_ASSET' => Icons.attach_file_rounded,
    _ => Icons.sync_problem_rounded,
  };
}

String _shortId(String id) {
  if (id.length <= 12) return id;
  return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
}

String _friendlySyncError(String error) {
  final text = error.replaceFirst('Exception: ', '').trim();
  final lower = text.toLowerCase();
  String? hint;
  if (lower.contains('server chua ho tro') ||
      lower.contains('chua ho tro dong bo') ||
      lower.contains('chưa hỗ trợ')) {
    hint =
        'Phần dữ liệu này đang có trong hàng đợi, nhưng server chưa có API nhận loại đó.';
  } else if (lower.contains('khong tim thay email') ||
      lower.contains('không tìm thấy email')) {
    hint = 'Email này cần có tài khoản trên server trước khi thêm vào dự án.';
  } else if (lower.contains('unauthorized') ||
      lower.contains('401') ||
      lower.contains('can dang nhap') ||
      lower.contains('cần đăng nhập')) {
    hint =
        'Phiên đăng nhập có thể đã hết hạn, hãy đăng nhập lại rồi thử đồng bộ.';
  } else if (lower.contains('dependency') ||
      lower.contains('foreign key') ||
      lower.contains('thieu dependency') ||
      lower.contains('thiếu dependency')) {
    hint = 'Một dữ liệu liên quan chưa được đồng bộ lên server trước mục này.';
  } else if (lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('network') ||
      lower.contains('không có kết nối')) {
    hint =
        'Thiết bị chưa kết nối được tới server, hãy kiểm tra mạng hoặc địa chỉ API.';
  }
  return hint == null ? text : '$text\n$hint';
}
