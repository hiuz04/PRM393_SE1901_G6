import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/cinex_models.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/workspace_provider.dart';
import '../../../../repositories/cinex_repository.dart';
import '../../../synchronization/presentation/providers/sync_provider.dart';
import '../../../synchronization/presentation/screens/sync_center_screen.dart';
import '../project_labels.dart';
import 'project_workspace_v2_screen.dart';

class ProjectLauncherScreen extends StatefulWidget {
  const ProjectLauncherScreen({super.key});

  @override
  State<ProjectLauncherScreen> createState() => _ProjectLauncherScreenState();
}

class _ProjectLauncherScreenState extends State<ProjectLauncherScreen> {
  final _search = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          context.read<ProjectProvider>().load();
          _syncProvider(listen: false)?.refresh();
        },
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final sync = _syncProvider();
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: () => provider.load(search: _search.text.trim()),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _LauncherHeader(
                userName: user?.displayName ?? 'Nhà sáng tạo',
                search: _search,
                onSearch: () => provider.load(search: _search.text.trim()),
                onReload: () => provider.load(search: _search.text.trim()),
                onLogout: () => context.read<AuthProvider>().logout(),
                onSync: _openSyncCenter,
                isReloading: provider.loading,
                pendingSyncCount: sync?.summary.pendingTotal ?? 0,
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsStrip(projects: provider.projects),
            ),
            SliverToBoxAdapter(
              child: _QuickActions(
                hasProjects: provider.projects.isNotEmpty,
                onCreate: _showCreateProject,
                onCharacters: () => _openFirstProject(1),
                onLocations: () => _openFirstProject(1),
                onAnalytics: () => _openFirstProject(4),
                onSync: _openSyncCenter,
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingView(message: 'Đang tải dự án'),
              )
            else if (provider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorStateView(
                  message: provider.error!,
                  onRetry: provider.load,
                ),
              )
            else if (provider.projects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  title: 'Chưa có dự án',
                  message:
                      'Tạo không gian kịch bản với hồi, cảnh, diễn viên, bối cảnh và phân tích sản xuất.',
                  icon: Icons.movie_creation_rounded,
                  action: FilledButton.icon(
                    onPressed: _showCreateProject,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo dự án'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 1180
                        ? 4
                        : width >= 860
                            ? 3
                            : width >= 620
                                ? 2
                                : 1;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: columns == 1 ? 1.04 : 0.78,
                      ),
                      itemCount: provider.projects.length,
                      itemBuilder: (_, index) => _ProjectCard(
                        project: provider.projects[index],
                        onOpen: (project) => _openProject(project),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProject,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dự án mới'),
      ),
    );
  }

  void _openFirstProject(int initialIndex) {
    final projects = context.read<ProjectProvider>().projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy tạo một dự án trước')),
      );
      return;
    }
    _openProject(projects.first, initialIndex: initialIndex);
  }

  void _openProject(Project project, {int initialIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(
            context.read<CineXRepository>(),
            project,
          )..loadAll(),
          child: ProjectWorkspaceScreen(
            project: project,
            initialIndex: initialIndex,
          ),
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0.04, 0.04),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  void _openSyncCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
    );
  }

  SyncProvider? _syncProvider({bool listen = true}) {
    try {
      return Provider.of<SyncProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _showCreateProject() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CreateProjectSheet(
        onCreate: ({
          required title,
          genre,
          description,
          posterUrl,
          startDate,
          endDate,
          required maxShootingMinutesPerDay,
        }) {
          return context.read<ProjectProvider>().create(
                title,
                genre: genre,
                description: description,
                posterUrl: posterUrl,
                startDate: startDate,
                endDate: endDate,
                maxShootingMinutesPerDay: maxShootingMinutesPerDay,
              );
        },
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo dự án')),
      );
    }
  }
}

class _LauncherHeader extends StatelessWidget {
  const _LauncherHeader({
    required this.userName,
    required this.search,
    required this.onSearch,
    required this.onReload,
    required this.onLogout,
    required this.onSync,
    required this.isReloading,
    required this.pendingSyncCount,
  });

  final String userName;
  final TextEditingController search;
  final VoidCallback onSearch;
  final VoidCallback onReload;
  final VoidCallback onLogout;
  final VoidCallback onSync;
  final bool isReloading;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [CineXPalette.primary, CineXPalette.secondary],
                    ),
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rất vui gặp lại, $userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: CineXPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Studio CINE-X',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: CineXPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Tải lại dự án',
                  child: IconButton.filledTonal(
                    onPressed: isReloading ? null : onReload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Trung tâm đồng bộ',
                  child: Badge(
                    isLabelVisible: pendingSyncCount > 0,
                    label: Text('$pendingSyncCount'),
                    child: IconButton.filledTonal(
                      onPressed: onSync,
                      icon: const Icon(Icons.cloud_sync_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Đăng xuất',
                  child: IconButton.filledTonal(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm dự án, thể loại hoặc ghi chú sản xuất',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => p.status == 'ACTIVE').length;
    final averageProgress = projects.isEmpty
        ? 0
        : projects
                .map((p) => p.progressPercent)
                .fold<double>(0, (sum, value) => sum + value) /
            projects.length;
    final edited = projects
        .where((p) => p.updatedAt != null || p.createdAt != null)
        .toList()
      ..sort(
        (a, b) => (b.updatedAt ?? b.createdAt!)
            .compareTo(a.updatedAt ?? a.createdAt!),
      );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final cards = [
            _StatCard(
              icon: Icons.folder_special_rounded,
              label: 'Dự án',
              value: '${projects.length}',
              accent: CineXPalette.primary,
            ),
            _StatCard(
              icon: Icons.bolt_rounded,
              label: 'Đang chạy',
              value: '$active',
              accent: CineXPalette.accent,
            ),
            _StatCard(
              icon: Icons.donut_large_rounded,
              label: 'Tiến độ TB',
              value: '${averageProgress.toStringAsFixed(0)}%',
              accent: CineXPalette.success,
            ),
            _StatCard(
              icon: Icons.schedule_rounded,
              label: 'Sửa gần đây',
              value: edited.isEmpty ? '--' : _formatShortDate(edited.first),
              accent: CineXPalette.secondary,
            ),
          ];
          if (compact) {
            return SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) => SizedBox(
                  width: 190,
                  child: cards[index],
                ),
              ),
            );
          }
          return GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.2,
            children: cards,
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.hasProjects,
    required this.onCreate,
    required this.onCharacters,
    required this.onLocations,
    required this.onAnalytics,
    required this.onSync,
  });

  final bool hasProjects;
  final VoidCallback onCreate;
  final VoidCallback onCharacters;
  final VoidCallback onLocations;
  final VoidCallback onAnalytics;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thao tác nhanh',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionChipButton(
                icon: Icons.add_rounded,
                label: 'Tạo dự án',
                onTap: onCreate,
              ),
              _ActionChipButton(
                icon: Icons.groups_rounded,
                label: 'Nhân vật',
                enabled: hasProjects,
                onTap: onCharacters,
              ),
              _ActionChipButton(
                icon: Icons.location_on_rounded,
                label: 'Bối cảnh',
                enabled: hasProjects,
                onTap: onLocations,
              ),
              _ActionChipButton(
                icon: Icons.insights_rounded,
                label: 'Phân tích',
                enabled: hasProjects,
                onTap: onAnalytics,
              ),
              _ActionChipButton(
                icon: Icons.cloud_sync_rounded,
                label: 'Đồng bộ',
                onTap: onSync,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? CineXPalette.textPrimary : CineXPalette.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CineXPalette.surface.withAlpha(188),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CineXPalette.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: CineXPalette.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CineXPalette.divider),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withAlpha(32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: CineXPalette.textPrimary,
                        ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CineXPalette.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({required this.project, required this.onOpen});

  final Project project;
  final ValueChanged<Project> onOpen;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Hero(
        tag: 'project-${project.id}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onOpen(project),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: CineXPalette.card,
                boxShadow: [
                  BoxShadow(
                    color: CineXPalette.primary.withAlpha(24),
                    blurRadius: 34,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProjectPoster(project: project),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x11000000),
                            Color(0x77101218),
                            Color(0xEE101218),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _MiniChip(
                                label: projectStatusLabel(project.status),
                                color: CineXPalette.success,
                              ),
                              const Spacer(),
                              _ProgressRing(
                                value: project.progressPercent / 100,
                                label:
                                    '${project.progressPercent.toStringAsFixed(0)}%',
                                size: 58,
                              ),
                            ],
                          ),
                          const Spacer(),
                          _MiniChip(
                            label: project.genre?.trim().isEmpty ?? true
                                ? 'Chưa có thể loại'
                                : project.genre!,
                            color: CineXPalette.accent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            project.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 24,
                                  height: 1.08,
                                ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Expanded(
                                child: _ProjectMeta(
                                  icon: Icons.view_kanban_rounded,
                                  label: 'Cảnh',
                                  value: '--',
                                ),
                              ),
                              Expanded(
                                child: _ProjectMeta(
                                  icon: Icons.groups_rounded,
                                  label: 'Vai',
                                  value: '--',
                                ),
                              ),
                              Expanded(
                                child: _ProjectMeta(
                                  icon: Icons.location_on_rounded,
                                  label: 'Bối cảnh',
                                  value: '--',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: CineXPalette.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Sửa lần cuối ${_formatRelative(project)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: CineXPalette.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectPoster extends StatelessWidget {
  const _ProjectPoster({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final url = project.posterUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _PosterFallback(project: project),
      );
    }
    return _PosterFallback(project: project);
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final palettes = [
      const [Color(0xFF222642), Color(0xFF6C63FF), Color(0xFF14151B)],
      const [Color(0xFF2B1F3A), Color(0xFF8B5CF6), Color(0xFF101218)],
      const [Color(0xFF302B19), Color(0xFFFFB800), Color(0xFF151515)],
      const [Color(0xFF17322A), Color(0xFF2ECC71), Color(0xFF101218)],
    ];
    final colors = palettes[project.id.abs() % palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_movies_rounded,
          color: Colors.white.withAlpha(170),
          size: 84,
        ),
      ),
    );
  }
}

class _ProjectMeta extends StatelessWidget {
  const _ProjectMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: CineXPalette.textPrimary),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CineXPalette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.label,
    this.size = 64,
  });

  final double value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: clamped,
            strokeWidth: 5,
            backgroundColor: Colors.white.withAlpha(28),
            color: CineXPalette.accent,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  const _CreateProjectSheet({required this.onCreate});

  final Future<bool> Function({
    required String title,
    String? genre,
    String? description,
    String? posterUrl,
    DateTime? startDate,
    DateTime? endDate,
    required int maxShootingMinutesPerDay,
  }) onCreate;

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _genre = TextEditingController();
  final _description = TextEditingController();
  final _posterUrl = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  final _maxMinutes = TextEditingController(text: '480');
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _genre.dispose();
    _description.dispose();
    _posterUrl.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _maxMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CineXPalette.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Tạo dự án',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thiết lập không gian điện ảnh cho kịch bản mới.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CineXPalette.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _posterUrl,
                builder: (context, value, child) {
                  final url = value.text.trim();
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: CineXPalette.divider),
                      color: CineXPalette.surface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: url.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: CineXPalette.textSecondary,
                              size: 42,
                            ),
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: CineXPalette.textSecondary,
                                size: 42,
                              ),
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề dự án',
                  prefixIcon: Icon(Icons.movie_creation_rounded),
                ),
                validator: ProjectValidators.title,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _genre,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Thể loại',
                  prefixIcon: Icon(Icons.theater_comedy_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _posterUrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'URL poster',
                  prefixIcon: Icon(Icons.image_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Logline hoặc ghi chú sản xuất',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDate,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Ngày bắt đầu',
                        prefixIcon: Icon(Icons.event_available_rounded),
                      ),
                      onTap: () => _pickDate(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endDate,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Ngày kết thúc',
                        prefixIcon: Icon(Icons.event_busy_rounded),
                      ),
                      validator: (_) => ProjectValidators.dateRange(
                        _selectedStartDate,
                        _selectedEndDate,
                      ),
                      onTap: () => _pickDate(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _maxMinutes,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Số phút quay tối đa mỗi ngày',
                  prefixIcon: Icon(Icons.timer_rounded),
                ),
                validator: ProjectValidators.maxMinutes,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Tạo dự án'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await widget.onCreate(
      title: _title.text.trim(),
      genre: _emptyToNull(_genre.text),
      description: _emptyToNull(_description.text),
      posterUrl: _emptyToNull(_posterUrl.text),
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      maxShootingMinutesPerDay: int.parse(_maxMinutes.text.trim()),
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, ok);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _selectedStartDate : _selectedEndDate;
    final initialDate = current ?? _selectedStartDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    setState(() {
      if (start) {
        _selectedStartDate = date;
        _startDate.text = DateFormat.yMMMd('vi_VN').format(date);
      } else {
        _selectedEndDate = date;
        _endDate.text = DateFormat.yMMMd('vi_VN').format(date);
      }
    });
    _formKey.currentState?.validate();
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatShortDate(Project project) {
  final date = project.updatedAt ?? project.createdAt;
  if (date == null) return '--';
  return DateFormat.MMMd('vi_VN').format(date);
}

String _formatRelative(Project project) {
  final date = project.updatedAt ?? project.createdAt ?? project.startDate;
  if (date == null) return 'gần đây';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'hôm nay';
  if (days == 1) return 'hôm qua';
  if (days < 7) return '$days ngày trước';
  return DateFormat.MMMd('vi_VN').format(date);
}
