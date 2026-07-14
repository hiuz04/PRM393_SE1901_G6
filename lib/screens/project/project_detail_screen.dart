import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/act.dart';
import '../../models/dashboard_summary.dart';
import '../../models/project.dart';
import '../../providers/act_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/project_provider.dart';
import '../act/act_form_dialog.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final actProvider = context.watch<ActProvider>();
    final project = projectProvider.selectedProject?.id == widget.projectId
        ? projectProvider.selectedProject
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.title ?? 'Project Details'),
        actions: [
          if (project != null)
            IconButton(
              tooltip: 'Edit project',
              onPressed: () => _editProject(project),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _buildBody(
        projectProvider,
        dashboardProvider,
        actProvider,
        project,
      ),
    );
  }

  Widget _buildBody(
    ProjectProvider projectProvider,
    DashboardProvider dashboardProvider,
    ActProvider actProvider,
    Project? project,
  ) {
    if (projectProvider.isLoading && project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (project == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            projectProvider.errorMessage ?? 'Project was not found.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjectWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProjectInfo(project: project),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Dashboard',
            icon: Icons.insights_outlined,
            trailing: dashboardProvider.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _DashboardSection(provider: dashboardProvider),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Acts',
            icon: Icons.view_timeline_outlined,
            trailing: FilledButton.icon(
              onPressed: () => _openActDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Act'),
            ),
          ),
          const SizedBox(height: 12),
          _ActsSection(
            provider: actProvider,
            onEdit: _openActDialog,
            onDelete: _confirmDeleteAct,
          ),
        ],
      ),
    );
  }

  Future<void> _loadProjectWorkspace() async {
    final projectProvider = context.read<ProjectProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final actProvider = context.read<ActProvider>();

    await Future.wait([
      projectProvider.loadProject(widget.projectId),
      dashboardProvider.loadDashboard(widget.projectId),
      actProvider.loadActs(widget.projectId),
    ]);
  }

  Future<void> _editProject(Project project) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProjectFormScreen(project: project)),
    );

    if (!mounted || result != true) {
      return;
    }

    await _loadProjectWorkspace();
  }

  Future<void> _openActDialog([Act? act]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ActFormDialog(projectId: widget.projectId, act: act),
    );

    if (!mounted || result != true) {
      return;
    }

    await context.read<DashboardProvider>().loadDashboard(widget.projectId);
  }

  Future<void> _confirmDeleteAct(Act act) async {
    final id = act.id;
    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete act?'),
          content: Text('Delete "${act.title}" from this project?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final actProvider = context.read<ActProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await actProvider.deleteAct(id);

    if (success) {
      await dashboardProvider.loadDashboard(widget.projectId);
    }

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Act deleted.'
              : actProvider.errorMessage ?? 'Could not delete act.',
        ),
      ),
    );
  }
}

class _ProjectInfo extends StatelessWidget {
  const _ProjectInfo({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.category_outlined,
                label: _optionalText(project.genre, fallback: 'No genre'),
              ),
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: _formatDate(project.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _optionalText(
              project.description,
              fallback: 'No description has been added yet.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  static String _optionalText(String? value, {required String fallback}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }

    return text;
  }

  static String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return 'Date not set';
    }

    return DateFormat.yMMMd().format(parsed.toLocal());
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.provider});

  final DashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final summary = provider.summary ?? DashboardSummary.empty();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680
                ? 4
                : constraints.maxWidth >= 360
                ? 2
                : 1;

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 118,
              ),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 4,
              itemBuilder: (context, index) {
                final tiles = [
                  _SummaryTile(
                    label: 'Characters',
                    value: summary.totalCharacters.toString(),
                    icon: Icons.groups_outlined,
                  ),
                  _SummaryTile(
                    label: 'Scenes',
                    value: summary.totalScenes.toString(),
                    icon: Icons.movie_filter_outlined,
                  ),
                  _SummaryTile(
                    label: 'Done',
                    value: summary.doneScenes.toString(),
                    icon: Icons.check_circle_outline,
                  ),
                  _SummaryTile(
                    label: 'Progress',
                    value: '${summary.progressPercentage}%',
                    icon: Icons.trending_up,
                  ),
                ];

                return tiles[index];
              },
            );
          },
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: summary.progress),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActsSection extends StatelessWidget {
  const _ActsSection({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  final ActProvider provider;
  final ValueChanged<Act> onEdit;
  final ValueChanged<Act> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.isLoading && provider.acts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.acts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.view_agenda_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              provider.errorMessage ?? 'No acts yet. Add the first act.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: provider.acts.map((act) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(child: Text(act.sequenceOrder.toString())),
            title: Text(act.title),
            subtitle: Text('Sequence order ${act.sequenceOrder}'),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Edit act',
                  onPressed: () => onEdit(act),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete act',
                  onPressed: () => onDelete(act),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
