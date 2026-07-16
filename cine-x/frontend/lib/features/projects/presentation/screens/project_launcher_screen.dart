import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/cinex_models.dart';
import '../../data/repositories/cinex_repository.dart';
import '../providers/project_provider.dart';
import '../providers/workspace_provider.dart';
import 'project_workspace_screen.dart';

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
        (_) => context.read<ProjectProvider>().load(),
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
                userName: user?.displayName ?? 'Creator',
                search: _search,
                onSearch: () => provider.load(search: _search.text.trim()),
                onLogout: () => context.read<AuthProvider>().logout(),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatsStrip(projects: provider.projects),
            ),
            SliverToBoxAdapter(
              child: _QuickActions(
                hasProjects: provider.projects.isNotEmpty,
                onCreate: _showCreateProject,
                onCharacters: () => _openFirstProject(2),
                onLocations: () => _openFirstProject(3),
                onAnalytics: () => _openFirstProject(4),
              ),
            ),
            if (provider.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingView(message: 'Loading projects'),
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
                  title: 'No projects yet',
                  message:
                      'Create a screenplay workspace with acts, scenes, cast, locations, and production analytics.',
                  icon: Icons.movie_creation_rounded,
                  action: FilledButton.icon(
                    onPressed: _showCreateProject,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create project'),
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
        label: const Text('New project'),
      ),
    );
  }

  void _openFirstProject(int initialIndex) {
    final projects = context.read<ProjectProvider>().projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a project first')),
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
        }) {
          return context.read<ProjectProvider>().create(
                title,
                genre: genre,
                description: description,
                posterUrl: posterUrl,
              );
        },
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created')),
      );
    }
  }
}

class _LauncherHeader extends StatelessWidget {
  const _LauncherHeader({
    required this.userName,
    required this.search,
    required this.onSearch,
    required this.onLogout,
  });

  final String userName;
  final TextEditingController search;
  final VoidCallback onSearch;
  final VoidCallback onLogout;

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
                        'Good to see you, $userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: CineXPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'CINE-X Studio',
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
                  message: 'Sign out',
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
                hintText: 'Search projects, genres, or production notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
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
              label: 'Projects',
              value: '${projects.length}',
              accent: CineXPalette.primary,
            ),
            _StatCard(
              icon: Icons.bolt_rounded,
              label: 'Active',
              value: '$active',
              accent: CineXPalette.accent,
            ),
            _StatCard(
              icon: Icons.donut_large_rounded,
              label: 'Average progress',
              value: '${averageProgress.toStringAsFixed(0)}%',
              accent: CineXPalette.success,
            ),
            _StatCard(
              icon: Icons.schedule_rounded,
              label: 'Last edited',
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
  });

  final bool hasProjects;
  final VoidCallback onCreate;
  final VoidCallback onCharacters;
  final VoidCallback onLocations;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
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
                label: 'Create project',
                onTap: onCreate,
              ),
              _ActionChipButton(
                icon: Icons.groups_rounded,
                label: 'Characters',
                enabled: hasProjects,
                onTap: onCharacters,
              ),
              _ActionChipButton(
                icon: Icons.location_on_rounded,
                label: 'Locations',
                enabled: hasProjects,
                onTap: onLocations,
              ),
              _ActionChipButton(
                icon: Icons.insights_rounded,
                label: 'Analytics',
                enabled: hasProjects,
                onTap: onAnalytics,
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
                                label: project.status,
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
                                ? 'Genre unset'
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
                                  label: 'Scenes',
                                  value: '--',
                                ),
                              ),
                              Expanded(
                                child: _ProjectMeta(
                                  icon: Icons.groups_rounded,
                                  label: 'Cast',
                                  value: '--',
                                ),
                              ),
                              Expanded(
                                child: _ProjectMeta(
                                  icon: Icons.location_on_rounded,
                                  label: 'Places',
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
                                  'Last edited ${_formatRelative(project)}',
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
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _genre.dispose();
    _description.dispose();
    _posterUrl.dispose();
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
                'Create project',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set up a cinematic workspace for a new screenplay.',
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
                  labelText: 'Project title',
                  prefixIcon: Icon(Icons.movie_creation_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a project title'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _genre,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Genre',
                  prefixIcon: Icon(Icons.theater_comedy_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _posterUrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Poster image URL',
                  prefixIcon: Icon(Icons.image_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Logline or production note',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
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
                label: const Text('Create project'),
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
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, ok);
    }
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatShortDate(Project project) {
  final date = project.updatedAt ?? project.createdAt;
  if (date == null) return '--';
  return DateFormat.MMMd().format(date);
}

String _formatRelative(Project project) {
  final date = project.updatedAt ?? project.createdAt ?? project.startDate;
  if (date == null) return 'recently';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return DateFormat.MMMd().format(date);
}
