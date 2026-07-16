import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/cinex_models.dart';
import '../project_labels.dart';
import '../providers/workspace_provider.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  const ProjectWorkspaceScreen({
    super.key,
    required this.project,
    this.initialIndex = 0,
  });

  final Project project;
  final int initialIndex;

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  late int _index;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: 'Overview',
    ),
    NavigationDestination(
      icon: Icon(Icons.view_kanban_outlined),
      selectedIcon: Icon(Icons.view_kanban_rounded),
      label: 'Storyboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups_rounded),
      label: 'Characters',
    ),
    NavigationDestination(
      icon: Icon(Icons.location_on_outlined),
      selectedIcon: Icon(Icons.location_on_rounded),
      label: 'Locations',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Analytics',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _destinations.length - 1).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final pages = [
      const _OverviewPage(),
      const _StoryboardPage(),
      const _CharactersPage(),
      const _LocationsPage(),
      const _AnalyticsPage(),
    ];

    Widget content;
    if (provider.loading && provider.dashboard == null) {
      content = const LoadingView(message: 'Preparing project workspace');
    } else if (provider.error != null && provider.dashboard == null) {
      content = ErrorStateView(
        message: provider.error!,
        onRetry: provider.loadAll,
      );
    } else {
      content = _WorkspaceContent(
        index: _index,
        project: widget.project,
        page: pages[_index],
      );
    }

    return Scaffold(
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          if (!wide) return content;
          return Row(
            children: [
              _WorkspaceRail(
                selectedIndex: _index,
                destinations: _destinations,
                onSelected: (value) => setState(() => _index = value),
              ),
              const VerticalDivider(width: 1, color: CineXPalette.divider),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 860) return const SizedBox.shrink();
          return _FloatingNavigation(
            selectedIndex: _index,
            destinations: _destinations,
            onSelected: (value) => setState(() => _index = value),
          );
        },
      ),
      floatingActionButton: _WorkspaceFab(index: _index),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.index,
    required this.project,
    required this.page,
  });

  final int index;
  final Project project;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _ProjectHeroHeader(project: project),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0.02, 0.02),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(key: ValueKey(index), child: page),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.all,
          groupAlignment: -0.7,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [CineXPalette.primary, CineXPalette.secondary],
                ),
              ),
              child:
                  const Icon(Icons.movie_filter_rounded, color: Colors.white),
            ),
          ),
          destinations: destinations
              .map(
                (destination) => NavigationRailDestination(
                  icon: destination.icon,
                  selectedIcon: destination.selectedIcon,
                  label: Text(destination.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _FloatingNavigation extends StatelessWidget {
  const _FloatingNavigation({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha(18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(55),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: destinations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectHeroHeader extends StatelessWidget {
  const _ProjectHeroHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final dashboard = provider.dashboard;
    final progress =
        ((dashboard?.progressPercent ?? project.progressPercent) / 100)
            .clamp(0.0, 1.0)
            .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: CineXPalette.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: CineXPalette.divider),
              boxShadow: [
                BoxShadow(
                  color: CineXPalette.primary.withAlpha(22),
                  blurRadius: 38,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCover(project: project, height: 150),
                        const SizedBox(height: 14),
                        _HeroDetails(
                          project: project,
                          progress: progress,
                          dashboard: dashboard,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 230,
                          child: _HeroCover(project: project, height: 150),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _HeroDetails(
                            project: project,
                            progress: progress,
                            dashboard: dashboard,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.project, required this.height});

  final Project project;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'project-${project.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ProjectCoverImage(project: project),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xDD0F1115)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: _SoftChip(
                  label: project.genre?.trim().isEmpty ?? true
                      ? 'Creative workspace'
                      : project.genre!,
                  color: CineXPalette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCoverImage extends StatelessWidget {
  const _ProjectCoverImage({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final url = project.posterUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _CoverFallback(project: project),
      );
    }
    return _CoverFallback(project: project);
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF252941), CineXPalette.primary, Color(0xFF11131A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_movies_rounded,
          color: Colors.white.withAlpha(170),
          size: 64,
        ),
      ),
    );
  }
}

class _HeroDetails extends StatelessWidget {
  const _HeroDetails({
    required this.project,
    required this.progress,
    required this.dashboard,
  });

  final Project project;
  final double progress;
  final Dashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    project.description?.trim().isEmpty ?? true
                        ? 'Plan acts, scenes, locations, cast, and production rhythm.'
                        : project.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: CineXPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ProgressRing(
              value: progress,
              label: '${(progress * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroMetric(
              icon: Icons.view_kanban_rounded,
              label: 'Scenes',
              value: '${dashboard?.totalScenes ?? 0}',
            ),
            _HeroMetric(
              icon: Icons.groups_rounded,
              label: 'Characters',
              value: '${dashboard?.totalCharacters ?? 0}',
            ),
            _HeroMetric(
              icon: Icons.location_on_rounded,
              label: 'Locations',
              value: '${dashboard?.totalLocations ?? 0}',
            ),
            _HeroMetric(
              icon: Icons.check_circle_rounded,
              label: 'Done',
              value: '${dashboard?.doneScenes ?? 0}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: context.read<WorkspaceProvider>().loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Edit project',
              onPressed: () => _showFeatureMessage(context, 'Project editing'),
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Export PDF',
              onPressed: () => _exportPdf(context),
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Share',
              onPressed: () => _showFeatureMessage(context, 'Project sharing'),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(170),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CineXPalette.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: CineXPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
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

class _WorkspaceFab extends StatelessWidget {
  const _WorkspaceFab({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final (icon, label, action) = switch (index) {
      1 => (
          provider.acts.isEmpty
              ? Icons.playlist_add_rounded
              : Icons.add_rounded,
          provider.acts.isEmpty ? 'New act' : 'New scene',
          () {
            if (provider.acts.isEmpty) {
              _showActSheet(context);
            } else if (provider.locations.isEmpty) {
              _showLocationSheet(context);
            } else {
              _showSceneSheet(context);
            }
          },
        ),
      2 => (
          Icons.person_add_alt_rounded,
          'New character',
          () => _showCharacterSheet(context),
        ),
      3 => (
          Icons.add_location_alt_rounded,
          'New location',
          () => _showLocationSheet(context),
        ),
      4 => (
          Icons.picture_as_pdf_rounded,
          'Export',
          () => _exportPdf(context),
        ),
      _ => (
          Icons.add_rounded,
          'New scene',
          () {
            if (provider.acts.isEmpty) {
              _showActSheet(context);
            } else if (provider.locations.isEmpty) {
              _showLocationSheet(context);
            } else {
              _showSceneSheet(context);
            }
          },
        ),
    };

    return FloatingActionButton.extended(
      onPressed: provider.loading ? null : action,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final dashboard = provider.dashboard;
    if (dashboard == null) return const LoadingView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
      children: [
        _MetricGrid(dashboard: dashboard),
        const SizedBox(height: 18),
        _ProgressPanel(dashboard: dashboard),
        const SizedBox(height: 18),
        _OverviewFocus(provider: provider),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricTile(
        label: 'Acts',
        value: '${dashboard.totalActs}',
        icon: Icons.format_list_numbered_rounded,
        color: CineXPalette.primary,
      ),
      _MetricTile(
        label: 'Scenes',
        value: '${dashboard.totalScenes}',
        icon: Icons.view_kanban_rounded,
        color: CineXPalette.accent,
      ),
      _MetricTile(
        label: 'Characters',
        value: '${dashboard.totalCharacters}',
        icon: Icons.groups_rounded,
        color: CineXPalette.secondary,
      ),
      _MetricTile(
        label: 'Locations',
        value: '${dashboard.totalLocations}',
        icon: Icons.location_on_rounded,
        color: CineXPalette.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.4 : 2.35,
          children: cards,
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withAlpha(32),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: CineXPalette.textPrimary,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CineXPalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final total = dashboard.totalScenes == 0 ? 1 : dashboard.totalScenes;
    return _GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final ring = _ProgressRing(
            value: dashboard.progressPercent / 100,
            label: '${dashboard.progressPercent.toStringAsFixed(0)}%',
            size: 88,
          );
          final bars = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Production progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 14),
              _ProgressBarRow(
                label: 'To do',
                value: dashboard.todoScenes,
                total: total,
                color: CineXPalette.textSecondary,
              ),
              _ProgressBarRow(
                label: 'In progress',
                value: dashboard.inProgressScenes,
                total: total,
                color: CineXPalette.warning,
              ),
              _ProgressBarRow(
                label: 'Done',
                value: dashboard.doneScenes,
                total: total,
                color: CineXPalette.success,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ring, const SizedBox(height: 18), bars],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 22),
              Expanded(child: bars),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewFocus extends StatelessWidget {
  const _OverviewFocus({required this.provider});

  final WorkspaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final nextScenes = provider.scenes
        .where((scene) => scene.status != 'DONE')
        .take(3)
        .toList();
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next creative moves',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          if (nextScenes.isEmpty)
            Text(
              'No open scenes yet. Add your first act or scene to start shaping the board.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CineXPalette.textSecondary,
                  ),
            )
          else
            ...nextScenes.map(
              (scene) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FocusSceneRow(scene: scene),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusSceneRow extends StatelessWidget {
  const _FocusSceneRow({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(scene.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(140),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${scene.sceneNumber}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene.title?.trim().isEmpty ?? true
                        ? 'Untitled scene'
                        : scene.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CineXPalette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${scene.locationName} / ${sceneStatusLabel(scene.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CineXPalette.textSecondary,
                      fontWeight: FontWeight.w700,
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

class _StoryboardPage extends StatelessWidget {
  const _StoryboardPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final acts = [...provider.acts]
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

    return Column(
      children: [
        _SectionToolbar(
          title: 'Storyboard',
          subtitle: 'Kanban-style act and scene planning.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showActSheet(context),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Act'),
            ),
            FilledButton.icon(
              onPressed: acts.isEmpty || provider.locations.isEmpty
                  ? null
                  : () => _showSceneSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Scene'),
            ),
          ],
        ),
        Expanded(
          child: acts.isEmpty
              ? EmptyView(
                  title: 'No acts yet',
                  message: 'Create the first act to begin arranging scenes.',
                  icon: Icons.view_kanban_rounded,
                  action: FilledButton.icon(
                    onPressed: () => _showActSheet(context),
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Create act'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    if (wide) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                        scrollDirection: Axis.horizontal,
                        itemCount: acts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, index) {
                          final act = acts[index];
                          final scenes = provider.scenes
                              .where((scene) => scene.actId == act.id)
                              .toList()
                            ..sort(
                              (a, b) => a.sceneNumber.compareTo(b.sceneNumber),
                            );
                          return SizedBox(
                            width: 360,
                            child: _ActColumn(
                              act: act,
                              scenes: scenes,
                              fillHeight: true,
                            ),
                          );
                        },
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                      itemCount: acts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, index) {
                        final act = acts[index];
                        final scenes = provider.scenes
                            .where((scene) => scene.actId == act.id)
                            .toList()
                          ..sort(
                            (a, b) => a.sceneNumber.compareTo(b.sceneNumber),
                          );
                        return _ActColumn(
                          act: act,
                          scenes: scenes,
                          fillHeight: false,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CineXPalette.textSecondary,
                    ),
              ),
            ],
          );
          final actionWrap =
              Wrap(spacing: 10, runSpacing: 10, children: actions);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  actionWrap,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleBlock),
              actionWrap,
            ],
          );
        },
      ),
    );
  }
}

class _ActColumn extends StatelessWidget {
  const _ActColumn({
    required this.act,
    required this.scenes,
    required this.fillHeight,
  });

  final Act act;
  final List<Scene> scenes;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CineXPalette.primary.withAlpha(34),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${act.sequenceOrder}',
                  style: const TextStyle(
                    color: CineXPalette.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: CineXPalette.textPrimary,
                        ),
                  ),
                  Text(
                    '${scenes.length} scenes',
                    style: const TextStyle(
                      color: CineXPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (act.description?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(
            act.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CineXPalette.textSecondary,
                ),
          ),
        ],
        const SizedBox(height: 14),
        if (scenes.isEmpty)
          _ActEmptyState(onCreate: () => _showSceneSheet(context))
        else if (fillHeight)
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: scenes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _SceneCard(scene: scenes[index]),
            ),
          )
        else
          ...scenes.map(
            (scene) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SceneCard(scene: scene),
            ),
          ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: fillHeight ? content : IntrinsicHeight(child: content),
      ),
    );
  }
}

class _ActEmptyState extends StatelessWidget {
  const _ActEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCreate,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 126,
        decoration: BoxDecoration(
          color: CineXPalette.surface.withAlpha(128),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CineXPalette.divider),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: CineXPalette.primary),
              SizedBox(height: 8),
              Text(
                'Add scene',
                style: TextStyle(
                  color: CineXPalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkspaceProvider>();
    final statusColor = _statusColor(scene.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(205),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withAlpha(95)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.drag_indicator_rounded,
                  color: CineXPalette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scene ${scene.sceneNumber}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        scene.title?.trim().isEmpty ?? true
                            ? 'Untitled scene'
                            : scene.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: CineXPalette.textPrimary,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Edit scene',
                  onPressed: () =>
                      _showFeatureMessage(context, 'Scene editing'),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SoftChip(
                  label: scene.locationName.isEmpty
                      ? 'Location unset'
                      : scene.locationName,
                  color: CineXPalette.primary,
                ),
                _SoftChip(
                  label: settingTypeLabel(scene.settingType),
                  color: CineXPalette.secondary,
                ),
                _SoftChip(
                  label: timeOfDayLabel(scene.timeOfDay),
                  color: CineXPalette.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              scene.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CineXPalette.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _statusProgress(scene.status),
                minHeight: 6,
                color: statusColor,
                backgroundColor: Colors.white.withAlpha(20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SceneAvatars(characters: scene.characters)),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withAlpha(90)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: scene.status,
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        dropdownColor: CineXPalette.surface,
                        style: const TextStyle(
                          color: CineXPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        items: const ['TODO', 'IN_PROGRESS', 'DONE']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(sceneStatusLabel(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.updateSceneStatus(scene, value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneAvatars extends StatelessWidget {
  const _SceneAvatars({required this.characters});

  final List<SceneCharacter> characters;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return const Text(
        'No cast attached',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: CineXPalette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final visible = characters.take(4).toList();
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 24,
              child: _SmallAvatar(
                name: visible[i].name,
                imageUrl: visible[i].imageUrl,
              ),
            ),
          if (characters.length > 4)
            Positioned(
              left: visible.length * 24,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: CineXPalette.divider,
                child: Text(
                  '+${characters.length - 4}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return CircleAvatar(
      radius: 17,
      backgroundColor: CineXPalette.primary,
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: url == null || url.isEmpty
          ? Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _CharactersPage extends StatelessWidget {
  const _CharactersPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    return Column(
      children: [
        _SectionToolbar(
          title: 'Characters',
          subtitle: 'A visual cast board for writing and directing.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showCharacterSheet(context),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Character'),
            ),
          ],
        ),
        Expanded(
          child: provider.characters.isEmpty
              ? EmptyView(
                  title: 'No characters yet',
                  message:
                      'Add the first character and build a visual cast wall.',
                  icon: Icons.groups_rounded,
                  action: FilledButton.icon(
                    onPressed: () => _showCharacterSheet(context),
                    icon: const Icon(Icons.person_add_alt_rounded),
                    label: const Text('Create character'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1120
                        ? 4
                        : constraints.maxWidth >= 820
                            ? 3
                            : constraints.maxWidth >= 560
                                ? 2
                                : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 1.14 : 0.78,
                      ),
                      itemCount: provider.characters.length,
                      itemBuilder: (_, index) {
                        final character = provider.characters[index];
                        final sceneCount = provider.scenes
                            .where(
                              (scene) => scene.characters.any(
                                (c) => c.id == character.id,
                              ),
                            )
                            .length;
                        return _CharacterCard(
                          character: character,
                          sceneCount: sceneCount,
                          onUpload: () async {
                            final file = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (file != null && context.mounted) {
                              provider.uploadCharacterImage(character, file);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CharacterCard extends StatefulWidget {
  const _CharacterCard({
    required this.character,
    required this.sceneCount,
    required this.onUpload,
  });

  final StoryCharacter character;
  final int sceneCount;
  final VoidCallback onUpload;

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final url = character.imageUrl?.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CineXPalette.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: CineXPalette.divider),
            boxShadow: [
              BoxShadow(
                color: CineXPalette.secondary.withAlpha(_hovered ? 36 : 18),
                blurRadius: _hovered ? 32 : 22,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'character-${character.id}',
                  child: url == null || url.isEmpty
                      ? _PortraitFallback(name: character.name)
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PortraitFallback(name: character.name),
                        ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x660F1115),
                        Color(0xF20F1115),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    tooltip: 'Upload portrait',
                    onPressed: widget.onUpload,
                    icon: const Icon(Icons.image_rounded),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SoftChip(
                        label: characterRoleLabel(character.roleType),
                        color: CineXPalette.secondary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        character.description?.trim().isEmpty ?? true
                            ? 'No character note yet.'
                            : character.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CineXPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.sceneCount} scenes',
                        style: const TextStyle(
                          color: CineXPalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242833), Color(0xFF6C63FF), Color(0xFF171A23)],
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LocationsPage extends StatelessWidget {
  const _LocationsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    return Column(
      children: [
        _SectionToolbar(
          title: 'Locations',
          subtitle: 'A travel-inspired map of cinematic spaces.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showLocationSheet(context),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Location'),
            ),
          ],
        ),
        Expanded(
          child: provider.locations.isEmpty
              ? EmptyView(
                  title: 'No locations yet',
                  message: 'Add interiors and exteriors for scene planning.',
                  icon: Icons.location_on_rounded,
                  action: FilledButton.icon(
                    onPressed: () => _showLocationSheet(context),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Create location'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1080
                        ? 3
                        : constraints.maxWidth >= 720
                            ? 2
                            : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 1.55 : 1.28,
                      ),
                      itemCount: provider.locations.length,
                      itemBuilder: (_, index) {
                        final location = provider.locations[index];
                        final sceneCount = provider.scenes
                            .where((scene) => scene.locationId == location.id)
                            .length;
                        return _LocationCard(
                          location: location,
                          sceneCount: sceneCount,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.sceneCount});

  final StoryLocation location;
  final int sceneCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CineXPalette.divider),
        boxShadow: [
          BoxShadow(
            color: CineXPalette.primary.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2F3542),
                    Color(0xFF242833),
                    Color(0xFF11131A)
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LocationTexturePainter(
                  exterior: location.settingType == 'EXT',
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xDD0F1115)],
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
                      _SoftChip(
                        label: settingTypeLabel(location.settingType),
                        color: CineXPalette.primary,
                      ),
                      const SizedBox(width: 8),
                      _SoftChip(
                        label: timeOfDayLabel(location.timeOfDay),
                        color: CineXPalette.accent,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    location.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    location.notes?.trim().isEmpty ?? true
                        ? 'No production note yet.'
                        : location.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CineXPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.view_kanban_rounded,
                        color: CineXPalette.textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$sceneCount scenes',
                        style: const TextStyle(
                          color: CineXPalette.textPrimary,
                          fontWeight: FontWeight.w900,
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
    );
  }
}

class _LocationTexturePainter extends CustomPainter {
  const _LocationTexturePainter({required this.exterior});

  final bool exterior;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = exterior
          ? CineXPalette.success.withAlpha(34)
          : CineXPalette.secondary.withAlpha(34);
    for (var i = -size.height; i < size.width; i += 34) {
      canvas.drawLine(
        Offset(i.toDouble(), size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LocationTexturePainter oldDelegate) =>
      oldDelegate.exterior != exterior;
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final analytics = provider.analytics ?? provider.dashboard;
    if (analytics == null) return const LoadingView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
      children: [
        _SectionToolbar(
          title: 'Analytics',
          subtitle: 'Premium production intelligence for scenes and cast.',
          actions: [
            FilledButton.icon(
              onPressed: () => _exportPdf(context),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Export PDF'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 820;
            final children = [
              _ScenePiePanel(analytics: analytics),
              _SceneBarPanel(analytics: analytics),
            ];
            if (!twoColumns) {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 16),
                  children[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 16),
                Expanded(child: children[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _PlannerTimeline(provider: provider),
        const SizedBox(height: 16),
        _CharacterFrequencyPanel(provider: provider),
      ],
    );
  }
}

class _ScenePiePanel extends StatelessWidget {
  const _ScenePiePanel({required this.analytics});

  final Dashboard analytics;

  @override
  Widget build(BuildContext context) {
    final total = analytics.totalScenes;
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scene status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: total == 0
                ? const Center(
                    child: Text(
                      'No chart data yet',
                      style: TextStyle(color: CineXPalette.textSecondary),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 48,
                      sections: [
                        PieChartSectionData(
                          value: analytics.todoScenes.toDouble(),
                          title: '${analytics.todoScenes}',
                          radius: 62,
                          color: CineXPalette.textSecondary,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        PieChartSectionData(
                          value: analytics.inProgressScenes.toDouble(),
                          title: '${analytics.inProgressScenes}',
                          radius: 70,
                          color: CineXPalette.warning,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        PieChartSectionData(
                          value: analytics.doneScenes.toDouble(),
                          title: '${analytics.doneScenes}',
                          radius: 76,
                          color: CineXPalette.success,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SceneBarPanel extends StatelessWidget {
  const _SceneBarPanel({required this.analytics});

  final Dashboard analytics;

  @override
  Widget build(BuildContext context) {
    final total = analytics.totalScenes == 0 ? 1 : analytics.totalScenes;
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scene workload',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 24),
          _ProgressBarRow(
            label: 'To do',
            value: analytics.todoScenes,
            total: total,
            color: CineXPalette.textSecondary,
          ),
          _ProgressBarRow(
            label: 'In progress',
            value: analytics.inProgressScenes,
            total: total,
            color: CineXPalette.warning,
          ),
          _ProgressBarRow(
            label: 'Done',
            value: analytics.doneScenes,
            total: total,
            color: CineXPalette.success,
          ),
          const SizedBox(height: 18),
          _ProgressRing(
            value: analytics.progressPercent / 100,
            label: '${analytics.progressPercent.toStringAsFixed(0)}%',
            size: 96,
          ),
        ],
      ),
    );
  }
}

class _PlannerTimeline extends StatelessWidget {
  const _PlannerTimeline({required this.provider});

  final WorkspaceProvider provider;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline by location',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          if (provider.planner.isEmpty)
            const Text(
              'No planner data yet.',
              style: TextStyle(
                color: CineXPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...provider.planner.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CineXPalette.surface.withAlpha(150),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CineXPalette.divider),
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: const Icon(Icons.place_rounded),
                    title: Text(group.location.name),
                    subtitle: Text(
                      '${group.sceneCount} scenes / ${group.totalEstimatedMinutes} min',
                    ),
                    children: group.scenes
                        .map(
                          (scene) => ListTile(
                            title: Text(
                              'Scene ${scene.sceneNumber}: ${scene.title?.trim().isEmpty ?? true ? 'Untitled' : scene.title!}',
                            ),
                            subtitle: Text(sceneStatusLabel(scene.status)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterFrequencyPanel extends StatelessWidget {
  const _CharacterFrequencyPanel({required this.provider});

  final WorkspaceProvider provider;

  @override
  Widget build(BuildContext context) {
    final maxScenes = provider.characterFrequency.isEmpty
        ? 1
        : provider.characterFrequency
            .map((item) => item.sceneCount)
            .reduce((a, b) => a > b ? a : b);
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Character frequency',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          if (provider.characterFrequency.isEmpty)
            const Text(
              'No character frequency data yet.',
              style: TextStyle(
                color: CineXPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...provider.characterFrequency.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FrequencyRow(item: item, maxScenes: maxScenes),
              ),
            ),
        ],
      ),
    );
  }
}

class _FrequencyRow extends StatelessWidget {
  const _FrequencyRow({required this.item, required this.maxScenes});

  final CharacterFrequency item;
  final int maxScenes;

  @override
  Widget build(BuildContext context) {
    final value = maxScenes == 0 ? 0.0 : item.sceneCount / maxScenes;
    return Row(
      children: [
        _SmallAvatar(name: item.name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CineXPalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${item.sceneCount}',
                    style: const TextStyle(
                      color: CineXPalette.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  color: CineXPalette.secondary,
                  backgroundColor: Colors.white.withAlpha(20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  const _ProgressBarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction =
        total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: CineXPalette.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: CineXPalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 560),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: 10,
                  color: color,
                  backgroundColor: Colors.white.withAlpha(20),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.label,
    this.size = 70,
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return CircularProgressIndicator(
                value: animatedValue,
                strokeWidth: size > 80 ? 8 : 6,
                color: CineXPalette.accent,
                backgroundColor: Colors.white.withAlpha(22),
              );
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: CineXPalette.textPrimary,
              fontSize: size > 80 ? 16 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(105)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CineXPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CineXPalette.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: CineXPalette.divider),
          boxShadow: [
            BoxShadow(
              color: CineXPalette.primary.withAlpha(18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

Future<void> _showActSheet(BuildContext context) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WorkspaceProvider>(),
      child: const _ActSheet(),
    ),
  );
}

Future<void> _showSceneSheet(BuildContext context) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WorkspaceProvider>(),
      child: const _SceneSheet(),
    ),
  );
}

Future<void> _showCharacterSheet(BuildContext context) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WorkspaceProvider>(),
      child: const _CharacterSheet(),
    ),
  );
}

Future<void> _showLocationSheet(BuildContext context) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WorkspaceProvider>(),
      child: const _LocationSheet(),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
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
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: CineXPalette.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CineXPalette.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActSheet extends StatefulWidget {
  const _ActSheet();

  @override
  State<_ActSheet> createState() => _ActSheetState();
}

class _ActSheetState extends State<_ActSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final TextEditingController _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WorkspaceProvider>();
    _order = TextEditingController(text: '${provider.acts.length + 1}');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Create act',
      subtitle: 'Add a vertical section to the storyboard.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Act title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an act title'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _order,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sequence order',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
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
                  : const Icon(Icons.playlist_add_rounded),
              label: const Text('Create act'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final ok = await provider.createAct(
      _title.text.trim(),
      int.tryParse(_order.text) ?? provider.acts.length + 1,
      description: _emptyToNull(_description.text),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

class _SceneSheet extends StatefulWidget {
  const _SceneSheet();

  @override
  State<_SceneSheet> createState() => _SceneSheetState();
}

class _SceneSheetState extends State<_SceneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _minutes = TextEditingController();
  late final TextEditingController _number;
  Act? _act;
  StoryLocation? _location;
  String _status = 'TODO';
  final Set<int> _selectedCharacters = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WorkspaceProvider>();
    _number = TextEditingController(text: '${provider.scenes.length + 1}');
    _act = provider.acts.isEmpty ? null : provider.acts.first;
    _location = provider.locations.isEmpty ? null : provider.locations.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _minutes.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    if (provider.acts.isEmpty || provider.locations.isEmpty) {
      return _SheetFrame(
        title: 'Create scene',
        subtitle: 'Scenes need at least one act and one location.',
        child: EmptyView(
          title: 'Setup needed',
          message: provider.acts.isEmpty
              ? 'Create an act before adding scenes.'
              : 'Create a location before adding scenes.',
          icon: Icons.tune_rounded,
        ),
      );
    }

    _act ??= provider.acts.first;
    _location ??= provider.locations.first;

    return _SheetFrame(
      title: 'Create scene',
      subtitle: 'Plan location, cast, status, and creative summary.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scene number',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Scene title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Act>(
              initialValue: _act,
              decoration: const InputDecoration(
                labelText: 'Act',
                prefixIcon: Icon(Icons.view_column_rounded),
              ),
              items: provider.acts
                  .map((act) =>
                      DropdownMenuItem(value: act, child: Text(act.title)))
                  .toList(),
              onChanged: (value) => setState(() => _act = value ?? _act),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<StoryLocation>(
              initialValue: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.place_rounded),
              ),
              items: provider.locations
                  .map(
                    (location) => DropdownMenuItem(
                      value: location,
                      child: Text(
                        '${location.name} / ${settingTypeLabel(location.settingType)} / ${timeOfDayLabel(location.timeOfDay)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _location = value ?? _location),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              items: const ['TODO', 'IN_PROGRESS', 'DONE']
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(sceneStatusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated minutes',
                prefixIcon: Icon(Icons.timer_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _summary,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Summary',
                prefixIcon: Icon(Icons.subject_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a scene summary'
                  : null,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Characters',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.characters
                    .map(
                      (character) => FilterChip(
                        label: Text(character.name),
                        selected: _selectedCharacters.contains(character.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _selectedCharacters.add(character.id)
                              : _selectedCharacters.remove(character.id),
                        ),
                      ),
                    )
                    .toList(),
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
              label: const Text('Create scene'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final act = _act;
    final location = _location;
    if (act == null || location == null) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final ok = await provider.createScene(
      sceneNumber: int.tryParse(_number.text) ?? provider.scenes.length + 1,
      actId: act.id,
      locationId: location.id,
      summary: _summary.text.trim(),
      status: _status,
      title: _emptyToNull(_title.text),
      estimatedMinutes: int.tryParse(_minutes.text),
      characterIds: _selectedCharacters.toList(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

class _CharacterSheet extends StatefulWidget {
  const _CharacterSheet();

  @override
  State<_CharacterSheet> createState() => _CharacterSheetState();
}

class _CharacterSheetState extends State<_CharacterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _role = 'MAIN';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Create character',
      subtitle: 'Add role, notes, and later attach a portrait.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              items: const ['MAIN', 'SUPPORT', 'CROWD']
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(characterRoleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Short description',
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
                  : const Icon(Icons.person_add_alt_rounded),
              label: const Text('Create character'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<WorkspaceProvider>().createCharacter(
          _name.text.trim(),
          _role,
          description: _emptyToNull(_description.text),
        );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  String _setting = 'INT';
  String _time = 'DAY';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Create location',
      subtitle: 'Track interiors, exteriors, and shooting time.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Location name',
                prefixIcon: Icon(Icons.place_rounded),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _setting,
              decoration: const InputDecoration(
                labelText: 'Setting',
                prefixIcon: Icon(Icons.meeting_room_rounded),
              ),
              items: const ['INT', 'EXT']
                  .map(
                    (setting) => DropdownMenuItem(
                      value: setting,
                      child: Text(settingTypeLabel(setting)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _setting = value ?? _setting),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _time,
              decoration: const InputDecoration(
                labelText: 'Time of day',
                prefixIcon: Icon(Icons.wb_twilight_rounded),
              ),
              items: const ['DAY', 'NIGHT']
                  .map(
                    (time) => DropdownMenuItem(
                      value: time,
                      child: Text(timeOfDayLabel(time)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _time = value ?? _time),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Production note',
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
                  : const Icon(Icons.add_location_alt_rounded),
              label: const Text('Create location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<WorkspaceProvider>().createLocation(
          _name.text.trim(),
          _setting,
          _time,
          notes: _emptyToNull(_notes.text),
        );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context, true);
    }
  }
}

Future<void> _exportPdf(BuildContext context) async {
  final bytes = await context.read<WorkspaceProvider>().exportPdf();
  if (bytes != null) {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to export PDF')),
    );
  }
}

void _showFeatureMessage(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature is ready for the next backend endpoint')),
  );
}

Color _statusColor(String status) {
  return switch (status) {
    'DONE' => CineXPalette.success,
    'IN_PROGRESS' => CineXPalette.warning,
    _ => CineXPalette.textSecondary,
  };
}

double _statusProgress(String status) {
  return switch (status) {
    'DONE' => 1,
    'IN_PROGRESS' => 0.55,
    _ => 0.12,
  };
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return '$first$second'.toUpperCase();
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
