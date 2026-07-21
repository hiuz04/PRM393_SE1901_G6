import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/cinex_models.dart';
import '../../../../providers/workspace_provider.dart';
import '../../../../services/image_storage_service.dart';
import '../../../../services/schedule_conflict_service.dart';
import '../project_labels.dart';

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
      icon: Icon(Icons.view_kanban_outlined),
      selectedIcon: Icon(Icons.view_kanban_rounded),
      label: 'Kịch bản',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: 'Tài nguyên',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Lịch quay',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Phân tích',
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
      const _StoryPage(),
      const _ResourcesPage(),
      const _CalendarPage(),
      const _AnalyticsPage(),
    ];

    final content = provider.loading && provider.dashboard == null
        ? const LoadingView(message: 'Đang chuẩn bị không gian ngoại tuyến')
        : provider.error != null && provider.dashboard == null
            ? ErrorStateView(
                message: provider.error!, onRetry: provider.loadAll)
            : SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _ProjectHeader(project: widget.project),
                    if (provider.error != null)
                      _InlineNotice(
                        icon: Icons.error_outline_rounded,
                        color: CineXPalette.danger,
                        message: provider.error!,
                      ),
                    Expanded(child: pages[_index]),
                  ],
                ),
              );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 860) return content;
          return Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
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
              const VerticalDivider(width: 1, color: CineXPalette.divider),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 860) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _destinations,
            ),
          );
        },
      ),
      floatingActionButton: _WorkspaceFab(index: _index),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final dashboard = provider.dashboard;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CineXPalette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CineXPalette.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Quay láº¡i',
                onPressed: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [CineXPalette.primary, CineXPalette.secondary],
                  ),
                ),
                child:
                    const Icon(Icons.movie_filter_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: CineXPalette.textPrimary,
                          ),
                    ),
                    Text(
                      '${dashboard?.totalScenes ?? 0} cảnh - '
                      '${dashboard?.totalCharacters ?? 0} nhân vật - '
                      '${dashboard?.totalResources ?? 0} tài nguyên',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CineXPalette.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Làm mới',
                onPressed: provider.loadAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Xuất PDF',
                onPressed: provider.can(ProjectPermission.exportProject)
                    ? () => _exportPdf(context)
                    : null,
                icon: const Icon(Icons.picture_as_pdf_rounded),
              ),
            ],
          ),
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
    final disabled = provider.loading;
    final (icon, label, permission, action) = switch (index) {
      0 => (
          provider.acts.isEmpty
              ? Icons.playlist_add_rounded
              : Icons.add_rounded,
          provider.acts.isEmpty ? 'Hồi mới' : 'Cảnh mới',
          ProjectPermission.manageStory,
          () => provider.acts.isEmpty
              ? _showActSheet(context)
              : _showSceneSheet(context),
        ),
      1 => (
          Icons.person_add_alt_rounded,
          'Nhân vật mới',
          ProjectPermission.manageCharacters,
          () => _showCharacterSheet(context),
        ),
      2 => (
          Icons.event_available_rounded,
          'Ngày quay mới',
          ProjectPermission.manageSchedule,
          () => _showShootingDaySheet(context),
        ),
      _ => (
          Icons.picture_as_pdf_rounded,
          'Xuất PDF',
          ProjectPermission.exportProject,
          () => _exportPdf(context),
        ),
    };
    return FloatingActionButton.extended(
      onPressed: disabled || !provider.can(permission) ? null : action,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    if (provider.acts.isEmpty) {
      return EmptyView(
        title: 'Chưa có hồi',
        message: 'Tạo một hồi trước khi thêm cảnh vào bảng kịch bản.',
        icon: Icons.view_column_rounded,
        action: FilledButton.icon(
          onPressed: provider.can(ProjectPermission.manageStory)
              ? () => _showActSheet(context)
              : null,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('Tạo hồi'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Bảng cảnh',
          actions: [
            _ToolbarAction(
              icon: Icons.playlist_add_rounded,
              tooltip: 'Tạo hồi',
              enabled: provider.can(ProjectPermission.manageStory),
              onPressed: () => _showActSheet(context),
            ),
            _ToolbarAction(
              icon: Icons.add_rounded,
              tooltip: 'Tạo cảnh',
              enabled: provider.can(ProjectPermission.manageStory),
              onPressed: () => _showSceneSheet(context),
            ),
          ],
        ),
        ...provider.acts.map((act) {
          final actScenes = provider.scenes
              .where((scene) => scene.actId == act.id)
              .toList()
            ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
          return _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${act.sequenceOrder}. ${act.title}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: CineXPalette.textPrimary,
                                ),
                      ),
                    ),
                    _Badge(label: '${actScenes.length} cảnh'),
                  ],
                ),
                if (act.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    act.description!,
                    style: const TextStyle(color: CineXPalette.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                if (actScenes.isEmpty)
                  const _MutedText('Chưa có cảnh trong hồi này.')
                else
                  ...actScenes.map((scene) => _SceneCard(scene: scene)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final canEdit = provider.can(ProjectPermission.manageStory);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    scene.sceneHeading,
                    style: const TextStyle(
                      color: CineXPalette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: canEdit,
                  onSelected: (value) async {
                    var ok = false;
                    if (value == 'delete') {
                      final confirmed = await _confirm(
                        context,
                        title: 'Xóa cảnh?',
                        message:
                            'Cảnh đã lên lịch sẽ được hủy thay vì xóa hẳn.',
                      );
                      if (!context.mounted || !confirmed) return;
                      ok = await provider.deleteScene(scene);
                    } else if (value == 'ready') {
                      ok = await provider.updateSceneStatus(
                        scene,
                        'READY_FOR_PLANNING',
                      );
                    } else if (value == 'done') {
                      ok = await provider.updateSceneStatus(scene, 'DONE');
                    }
                    if (context.mounted && ok) {
                      _snack(context, 'Đã cập nhật cảnh');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'ready', child: Text('Sẵn sàng lên lịch')),
                    PopupMenuItem(
                        value: 'done', child: Text('Đánh dấu viết xong')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa / hủy')),
                  ],
                ),
              ],
            ),
            if (scene.title != null) ...[
              const SizedBox(height: 4),
              Text(scene.title!,
                  style: const TextStyle(color: CineXPalette.accent)),
            ],
            const SizedBox(height: 8),
            Text(
              scene.summary,
              style: const TextStyle(color: CineXPalette.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(label: sceneStatusLabel(scene.writingStatus)),
                _Badge(label: productionStatusLabel(scene.productionStatus)),
                _Badge(label: '${scene.estimatedDurationMinutes} phút'),
                _Badge(label: 'Địa điểm quay: ${scene.shootingLocationLabel}'),
              ],
            ),
            if (scene.characters.isNotEmpty || scene.resources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (scene.characters.isNotEmpty)
                    'Diễn viên: ${scene.characters.map((item) => item.name).join(', ')}',
                  if (scene.resources.isNotEmpty)
                    'Tài nguyên: ${scene.resources.map((item) => '${item.name} x${item.requiredQuantity}').join(', ')}',
                ].join('\n'),
                style: const TextStyle(color: CineXPalette.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourcesPage extends StatelessWidget {
  const _ResourcesPage();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.groups_rounded), text: 'Nhân vật'),
              Tab(icon: Icon(Icons.place_rounded), text: 'Bối cảnh truyện'),
              Tab(
                  icon: Icon(Icons.location_city_rounded),
                  text: 'Địa điểm quay'),
              Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Tài nguyên'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CharactersList(),
                _StoryLocationsList(),
                _ShootingLocationsList(),
                _AssetsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharactersList extends StatelessWidget {
  const _CharactersList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    if (provider.characters.isEmpty) {
      return EmptyView(
        title: 'Chưa có nhân vật',
        icon: Icons.groups_rounded,
        action: FilledButton.icon(
          onPressed: provider.can(ProjectPermission.manageCharacters)
              ? () => _showCharacterSheet(context)
              : null,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Thêm nhân vật'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Nhân vật',
          actions: [
            _ToolbarAction(
              icon: Icons.person_add_alt_rounded,
              tooltip: 'Thêm nhân vật',
              enabled: provider.can(ProjectPermission.manageCharacters),
              onPressed: () => _showCharacterSheet(context),
            ),
          ],
        ),
        ...provider.characters.map(
          (character) => _Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: SafeLocalImage(path: character.imagePath),
                ),
              ),
              title: Text(character.name),
              subtitle: Text(
                '${characterRoleLabel(character.roleType)}\n'
                '${character.psychologicalDescription ?? 'Chưa có mô tả'}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Sửa nhân vật',
                    onPressed: provider.can(ProjectPermission.manageCharacters)
                        ? () =>
                            _showCharacterSheet(context, character: character)
                        : null,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Lưu trữ nhân vật',
                    onPressed: provider.can(ProjectPermission.manageCharacters)
                        ? () async {
                            final ok = await _confirm(
                              context,
                              title: 'Lưu trữ nhân vật?',
                              message:
                                  'Nhân vật đã dùng trong cảnh sẽ được lưu trữ để giữ nguyên liên kết cảnh.',
                            );
                            if (!ok || !context.mounted) return;
                            if (await provider.deleteCharacter(character) &&
                                context.mounted) {
                              _snack(context, 'Đã lưu trữ nhân vật');
                            }
                          }
                        : null,
                    icon: const Icon(Icons.archive_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryLocationsList extends StatelessWidget {
  const _StoryLocationsList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Bối cảnh truyện',
          actions: [
            _ToolbarAction(
              icon: Icons.add_location_alt_rounded,
              tooltip: 'Thêm bối cảnh truyện',
              enabled: provider.can(ProjectPermission.manageStoryLocations),
              onPressed: () => _showStoryLocationSheet(context),
            ),
          ],
        ),
        if (provider.storyLocations.isEmpty)
          const _Panel(child: _MutedText('Chưa có bối cảnh truyện.'))
        else
          ...provider.storyLocations.map(
            (location) => _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.theater_comedy_rounded),
                title: Text(location.name),
                subtitle: Text(location.description ??
                    location.notes ??
                    'Chưa có ghi chú'),
                trailing: IconButton(
                  tooltip: 'Sửa bối cảnh truyện',
                  onPressed: provider
                          .can(ProjectPermission.manageStoryLocations)
                      ? () =>
                          _showStoryLocationSheet(context, location: location)
                      : null,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShootingLocationsList extends StatelessWidget {
  const _ShootingLocationsList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Địa điểm quay thực tế',
          actions: [
            _ToolbarAction(
              icon: Icons.add_location_alt_rounded,
              tooltip: 'Thêm địa điểm quay',
              enabled: provider.can(ProjectPermission.manageShootingLocations),
              onPressed: () => _showShootingLocationSheet(context),
            ),
          ],
        ),
        if (provider.shootingLocations.isEmpty)
          const _Panel(child: _MutedText('Chưa có địa điểm quay thực tế.'))
        else
          ...provider.shootingLocations.map(
            (location) => _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_city_rounded),
                title: Text(location.name),
                subtitle: Text(
                  '${location.address}\n'
                  '${location.supportsInterior ? 'Nội cảnh' : ''} '
                  '${location.supportsExterior ? 'Ngoại cảnh' : ''}'
                  '${location.contactPhone == null ? '' : ' - ${location.contactPhone}'}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Sửa địa điểm quay',
                  onPressed:
                      provider.can(ProjectPermission.manageShootingLocations)
                          ? () => _showShootingLocationSheet(
                                context,
                                location: location,
                              )
                          : null,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AssetsList extends StatefulWidget {
  const _AssetsList();

  @override
  State<_AssetsList> createState() => _AssetsListState();
}

class _AssetsListState extends State<_AssetsList> {
  final _search = TextEditingController();
  String? _type;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Tài nguyên phim',
          actions: [
            _ToolbarAction(
              icon: Icons.add_box_rounded,
              tooltip: 'Thêm tài nguyên',
              enabled: provider.can(ProjectPermission.manageResources),
              onPressed: () => _showResourceSheet(context),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Tìm tài nguyên',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onSubmitted: (_) => provider.loadResources(
                  search: _search.text,
                  resourceType: _type,
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String?>(
              value: _type,
              hint: const Text('Loại'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tất cả')),
                ...ResourceValidators.validTypes.map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(resourceTypeLabel(type)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _type = value);
                provider.loadResources(
                    search: _search.text, resourceType: value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.resources.isEmpty)
          const _Panel(child: _MutedText('Chưa có tài nguyên phim.'))
        else
          ...provider.resources.map(
            (resource) => _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_rounded),
                title: Text(resource.name),
                subtitle: Text(
                  '${resourceTypeLabel(resource.resourceType)} - '
                  '${resource.quantityTotal} ${resource.unit ?? ''}\n'
                  '${resourceStatusLabel(resource.status ?? 'AVAILABLE')}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Sửa tài nguyên',
                  onPressed: provider.can(ProjectPermission.manageResources)
                      ? () => _showResourceSheet(context, resource: resource)
                      : null,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final activeSelectedDateDays =
        provider.selectedDateDays.where((day) => day.isActive).toList();
    final shootingDaysByDate = <DateTime, List<ShootingDay>>{};
    for (final day in provider.shootingDays) {
      shootingDaysByDate
          .putIfAbsent(_dateKey(day.shootingDate), () => <ShootingDay>[])
          .add(day);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Lịch sản xuất',
          actions: [
            _ToolbarAction(
              icon: Icons.auto_awesome_rounded,
              tooltip: 'Tạo lịch gợi ý',
              enabled: provider.can(ProjectPermission.manageSchedule),
              onPressed: () async {
                if (provider.unscheduledScenes.isEmpty) {
                  _snack(context, 'Không có cảnh sẵn sàng để tạo lịch.');
                  return;
                }
                final ok = await provider
                    .generateSuggestedSchedule(provider.selectedDate);
                if (!context.mounted) return;
                _snack(
                  context,
                  ok
                      ? 'Đã tạo lịch nháp gợi ý'
                      : provider.error ?? 'Không thể tạo lịch',
                );
              },
            ),
            _ToolbarAction(
              icon: Icons.event_available_rounded,
              tooltip: 'Tạo ngày quay',
              enabled: provider.can(ProjectPermission.manageSchedule),
              onPressed: () => _showShootingDaySheet(context),
            ),
          ],
        ),
        if (provider.conflicts.isNotEmpty)
          _ConflictPanel(conflicts: provider.conflicts),
        if (provider.scheduleWarnings.isNotEmpty)
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            color: CineXPalette.warning,
            message: provider.scheduleWarnings.join('\n'),
          ),
        _Panel(
          child: _ProductionCalendar(
            month: DateTime(
              provider.selectedDate.year,
              provider.selectedDate.month,
            ),
            selectedDate: provider.selectedDate,
            shootingDaysByDate: shootingDaysByDate,
            canManage: provider.can(ProjectPermission.manageSchedule),
            onDateSelected: (date) => provider.loadCalendar(date: date),
            onMonthChanged: (month) => provider.loadCalendar(date: month),
            onAddDay: (date) =>
                _showShootingDaySheet(context, initialDate: date),
            onEditDay: (day) => _showShootingDaySheet(context, day: day),
          ),
        ),
        Text(
          'Chi tiết ngày quay',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CineXPalette.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        _SelectedDateToolbar(
          date: provider.selectedDate,
          days: provider.selectedDateDays,
          canManage: provider.can(ProjectPermission.manageSchedule),
          onAdd: () => _showShootingDaySheet(context,
              initialDate: provider.selectedDate),
          onEdit: provider.selectedDateDays.length == 1
              ? () => _showShootingDaySheet(
                    context,
                    day: provider.selectedDateDays.first,
                  )
              : null,
        ),
        const SizedBox(height: 8),
        if (provider.selectedDateDays.isEmpty)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MutedText('Không có ngày quay vào ngày này.'),
                if (provider.can(ProjectPermission.manageSchedule)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showShootingDaySheet(
                      context,
                      initialDate: provider.selectedDate,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm ngày quay'),
                  ),
                ],
              ],
            ),
          )
        else
          ...provider.selectedDateDays.map((day) => _ShootingDayCard(day: day)),
        const SizedBox(height: 16),
        Text(
          'Cảnh sẵn sàng chưa lên lịch',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CineXPalette.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        if (provider.unscheduledScenes.isEmpty)
          const _Panel(
              child: _MutedText('Không có cảnh sẵn sàng lên lịch đang chờ.'))
        else
          ...provider.unscheduledScenes.map(
            (scene) => _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(scene.sceneHeading),
                subtitle: Text(
                  '${scene.shootingLocationLabel} · '
                  '${scene.estimatedDurationMinutes} phút',
                ),
                trailing: IconButton(
                  tooltip: activeSelectedDateDays.isEmpty
                      ? 'Tạo ngày quay trước'
                      : 'Xếp cảnh vào ngày đã chọn',
                  onPressed: provider.can(ProjectPermission.manageSchedule) &&
                          activeSelectedDateDays.isNotEmpty
                      ? () => _showScheduleSceneSheet(context, scene: scene)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedDateToolbar extends StatelessWidget {
  const _SelectedDateToolbar({
    required this.date,
    required this.days,
    required this.canManage,
    required this.onAdd,
    this.onEdit,
  });

  final DateTime date;
  final List<ShootingDay> days;
  final bool canManage;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            localizations.formatFullDate(date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CineXPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Thêm ngày quay',
          onPressed: canManage ? onAdd : null,
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip:
              days.length == 1 ? 'Sửa ngày quay' : 'Chọn một ngày quay để sửa',
          onPressed: canManage ? onEdit : null,
          icon: const Icon(Icons.edit_calendar_rounded),
        ),
      ],
    );
  }
}

class _ProductionCalendar extends StatelessWidget {
  const _ProductionCalendar({
    required this.month,
    required this.selectedDate,
    required this.shootingDaysByDate,
    required this.canManage,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.onAddDay,
    required this.onEditDay,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, List<ShootingDay>> shootingDaysByDate;
  final bool canManage;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onAddDay;
  final ValueChanged<ShootingDay> onEditDay;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(month.year, month.month);
    final visibleStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final visibleDates = List.generate(
      42,
      (index) => visibleStart.add(Duration(days: index)),
    );
    final localizations = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final cellHeight = compact ? 92.0 : 112.0;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizations.formatMonthYear(monthStart),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: CineXPalette.textPrimary,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed: () => onMonthChanged(
                    DateTime(monthStart.year, monthStart.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed: () => onMonthChanged(
                    DateTime(monthStart.year, monthStart.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                _WeekdayHeader(label: 'T2'),
                _WeekdayHeader(label: 'T3'),
                _WeekdayHeader(label: 'T4'),
                _WeekdayHeader(label: 'T5'),
                _WeekdayHeader(label: 'T6'),
                _WeekdayHeader(label: 'T7'),
                _WeekdayHeader(label: 'CN'),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleDates.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: cellHeight,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final date = visibleDates[index];
                final days = shootingDaysByDate[_dateKey(date)] ?? const [];
                return _CalendarDayCell(
                  date: date,
                  days: days,
                  inMonth: date.month == monthStart.month,
                  selected: _sameDate(date, selectedDate),
                  today: _sameDate(date, DateTime.now()),
                  compact: compact,
                  canManage: canManage,
                  onSelect: () => onDateSelected(date),
                  onAdd: () => onAddDay(date),
                  onEditDay: onEditDay,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CineXPalette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.days,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.compact,
    required this.canManage,
    required this.onSelect,
    required this.onAdd,
    required this.onEditDay,
  });

  final DateTime date;
  final List<ShootingDay> days;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool compact;
  final bool canManage;
  final VoidCallback onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ShootingDay> onEditDay;

  @override
  Widget build(BuildContext context) {
    final visibleDays = days.take(compact ? 2 : 3).toList();
    final statusColor = days.isEmpty
        ? CineXPalette.divider
        : _shootingDayStatusColor(days.first.status);
    final background = selected
        ? CineXPalette.primary.withAlpha(42)
        : inMonth
            ? CineXPalette.surface.withAlpha(110)
            : CineXPalette.background.withAlpha(90);
    final borderColor = selected
        ? CineXPalette.primary
        : today
            ? CineXPalette.accent.withAlpha(150)
            : CineXPalette.divider;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onSelect,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 24 : 28,
                      height: compact ? 24 : 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? CineXPalette.primary
                            : today
                                ? CineXPalette.accent.withAlpha(45)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: inMonth
                              ? CineXPalette.textPrimary
                              : CineXPalette.textSecondary.withAlpha(120),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (days.isNotEmpty)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    else if (canManage)
                      IconButton(
                        tooltip: 'Thêm ngày quay',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Column(
                    children: [
                      ...visibleDays.map(
                        (day) => _CalendarEventPill(
                          day: day,
                          compact: compact,
                          onTap: canManage ? () => onEditDay(day) : null,
                        ),
                      ),
                      if (days.length > visibleDays.length)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${days.length - visibleDays.length} lịch',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CineXPalette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
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

class _CalendarEventPill extends StatelessWidget {
  const _CalendarEventPill({
    required this.day,
    required this.compact,
    this.onTap,
  });

  final ShootingDay day;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _shootingDayStatusColor(day.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: '${day.title} - ${shootingDayStatusLabel(day.status)}',
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withAlpha(120)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: 3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      day.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CineXPalette.textPrimary,
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShootingDayCard extends StatelessWidget {
  const _ShootingDayCard({required this.day});

  final ShootingDay day;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final canSchedule = provider.can(ProjectPermission.manageSchedule);
    final canEditDay = canSchedule && day.isActive;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: canEditDay
                ? () => _showShootingDaySheet(context, day: day)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          day.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: CineXPalette.textPrimary,
                                  ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sửa ngày quay',
                        onPressed: canEditDay
                            ? () => _showShootingDaySheet(context, day: day)
                            : null,
                        icon: const Icon(Icons.edit_calendar_rounded),
                      ),
                      _Badge(label: shootingDayStatusLabel(day.status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: day.maxMinutes == 0
                        ? 0
                        : (day.totalMinutes / day.maxMinutes).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${day.totalMinutes}/${day.maxMinutes} phút',
                    style: const TextStyle(color: CineXPalette.textSecondary),
                  ),
                  if (day.notes != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      day.notes!,
                      style: const TextStyle(color: CineXPalette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (day.scenes.isEmpty)
            const _MutedText('Chưa có cảnh trong ngày quay này.')
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: day.scenes.length,
              onReorder: canEditDay
                  ? (oldIndex, newIndex) {
                      final ids =
                          day.scenes.map((item) => item.scene.id).toList();
                      if (newIndex > oldIndex) newIndex -= 1;
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      provider.reorderShootingDayScenes(day.id, ids);
                    }
                  : (_, __) {},
              itemBuilder: (_, index) {
                final item = day.scenes[index];
                return ListTile(
                  key: ValueKey('day-${day.id}-scene-${item.scene.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: canEditDay
                      ? ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle_rounded),
                        )
                      : const Icon(Icons.movie_creation_outlined),
                  title: Text(item.scene.sceneHeading),
                  subtitle: Text(
                    '${item.plannedStartTime ?? '--:--'} - '
                    '${item.plannedEndTime ?? '--:--'}',
                  ),
                  onTap: canEditDay
                      ? () => _showShootingSceneTimeSheet(
                            context,
                            day: day,
                            item: item,
                          )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sửa giờ quay',
                        onPressed: canEditDay
                            ? () => _showShootingSceneTimeSheet(
                                  context,
                                  day: day,
                                  item: item,
                                )
                            : null,
                        icon: const Icon(Icons.schedule_rounded),
                      ),
                      IconButton(
                        tooltip: 'Gỡ cảnh',
                        onPressed: canEditDay
                            ? () => provider.removeSceneFromShootingDay(
                                  day.id,
                                  item.scene.id,
                                )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: provider.can(ProjectPermission.confirmSchedule) &&
                        canEditDay
                    ? () async {
                        final ok = await provider.updateShootingDayStatus(
                          day.id,
                          'CONFIRMED',
                        );
                        if (context.mounted) {
                          _snack(
                              context,
                              ok
                                  ? 'Đã xác nhận lịch quay'
                                  : provider.error ?? 'Bị chặn bởi xung đột');
                        }
                      }
                    : null,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Xác nhận'),
              ),
              FilledButton.tonalIcon(
                onPressed: canEditDay
                    ? () =>
                        provider.updateShootingDayStatus(day.id, 'IN_PROGRESS')
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Đang quay'),
              ),
              FilledButton.tonalIcon(
                onPressed: canEditDay
                    ? () =>
                        provider.updateShootingDayStatus(day.id, 'COMPLETED')
                    : null,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Hoàn tất'),
              ),
              FilledButton.tonalIcon(
                onPressed: canEditDay
                    ? () =>
                        provider.updateShootingDayStatus(day.id, 'CANCELLED')
                    : null,
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Hủy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showScheduleSceneSheet(
  BuildContext context, {
  required Scene scene,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ScheduleSceneSheet(scene: scene),
    ),
  );
}

class _ScheduleSceneSheet extends StatefulWidget {
  const _ScheduleSceneSheet({required this.scene});

  final Scene scene;

  @override
  State<_ScheduleSceneSheet> createState() => _ScheduleSceneSheetState();
}

class _ScheduleSceneSheetState extends State<_ScheduleSceneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  int? _dayId;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final days = _activeSelectedDateDays(context.read<WorkspaceProvider>());
    if (days.isNotEmpty) {
      _dayId = days.first.id;
      _fillSuggestedTimes(days.first);
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final days = _activeSelectedDateDays(provider);
    final selectedDay = _selectedDay(days);
    final projectedMinutes = selectedDay == null
        ? null
        : selectedDay.totalMinutes + widget.scene.estimatedDurationMinutes;
    final overLimit = selectedDay != null &&
        projectedMinutes != null &&
        projectedMinutes > selectedDay.maxMinutes;

    return _SheetFrame(
      title: 'Xếp cảnh vào lịch',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SceneScheduleSummary(scene: widget.scene),
            const SizedBox(height: 12),
            if (days.isEmpty)
              const _InlineNotice(
                icon: Icons.info_outline_rounded,
                color: CineXPalette.warning,
                message: 'Ngày đang chọn chưa có ca quay nháp/đang hoạt động.',
              )
            else
              DropdownButtonFormField<int>(
                value: selectedDay?.id,
                decoration: const InputDecoration(labelText: 'Ngày quay'),
                items: [
                  for (final day in days)
                    DropdownMenuItem(
                      value: day.id,
                      child: Text(
                        '${day.title} · ${day.totalMinutes}/${day.maxMinutes} phút',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        final day = days.firstWhere(
                          (item) => item.id == value,
                          orElse: () => days.first,
                        );
                        setState(() {
                          _dayId = day.id;
                          _fillSuggestedTimes(day);
                        });
                      },
                validator: (value) =>
                    value == null ? 'Chọn ngày quay để xếp cảnh' : null,
              ),
            if (selectedDay != null) ...[
              const SizedBox(height: 10),
              Text(
                'Sau khi thêm: $projectedMinutes/${selectedDay.maxMinutes} phút',
                style: TextStyle(
                  color: overLimit
                      ? CineXPalette.danger
                      : CineXPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ScheduleTimeField(
                    controller: _start,
                    label: 'Bắt đầu',
                    onPick: () => _pickTime(_start),
                    validator: (_) =>
                        _timeRangeValidator(_start.text, _end.text),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScheduleTimeField(
                    controller: _end,
                    label: 'Kết thúc',
                    onPick: () => _pickTime(_end),
                    validator: (_) =>
                        _timeRangeValidator(_start.text, _end.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || days.isEmpty || overLimit ? null : _save,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm vào lịch'),
            ),
          ],
        ),
      ),
    );
  }

  List<ShootingDay> _activeSelectedDateDays(WorkspaceProvider provider) {
    return provider.selectedDateDays.where((day) => day.isActive).toList();
  }

  ShootingDay? _selectedDay(List<ShootingDay> days) {
    if (days.isEmpty) return null;
    for (final day in days) {
      if (day.id == _dayId) return day;
    }
    return days.first;
  }

  void _fillSuggestedTimes(ShootingDay day) {
    final start = _nextAvailableMinute(day);
    final end = start + widget.scene.estimatedDurationMinutes;
    if (!_setClockRange(start, end)) {
      _start.clear();
      _end.clear();
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _clockToMinutes(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _formatClock(picked.hour * 60 + picked.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _dayId == null) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final ok = await provider.addSceneToShootingDay(
      _dayId!,
      widget.scene.id,
      plannedStartTime: _emptyToNull(_start.text),
      plannedEndTime: _emptyToNull(_end.text),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      context,
      ok ? 'Đã thêm cảnh vào ngày quay' : provider.error ?? 'Không thể thêm cảnh',
    );
    if (ok) Navigator.pop(context, true);
  }

  bool _setClockRange(int start, int end) {
    if (start < 0 || end <= start || end >= 24 * 60) return false;
    _start.text = _formatClock(start);
    _end.text = _formatClock(end);
    return true;
  }
}

Future<void> _showShootingSceneTimeSheet(
  BuildContext context, {
  required ShootingDay day,
  required ShootingDayScene item,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ShootingSceneTimeSheet(day: day, item: item),
    ),
  );
}

class _ShootingSceneTimeSheet extends StatefulWidget {
  const _ShootingSceneTimeSheet({
    required this.day,
    required this.item,
  });

  final ShootingDay day;
  final ShootingDayScene item;

  @override
  State<_ShootingSceneTimeSheet> createState() => _ShootingSceneTimeSheetState();
}

class _ShootingSceneTimeSheetState extends State<_ShootingSceneTimeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final suggestedStart = _suggestedMinuteForScene(widget.day, widget.item);
    final suggestedEnd =
        suggestedStart + widget.item.scene.estimatedDurationMinutes;
    _start = TextEditingController(
      text: widget.item.plannedStartTime ??
          (_isValidClockMinute(suggestedStart)
              ? _formatClock(suggestedStart)
              : ''),
    );
    _end = TextEditingController(
      text: widget.item.plannedEndTime ??
          (_isValidClockMinute(suggestedEnd)
              ? _formatClock(suggestedEnd)
              : ''),
    );
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Sửa giờ quay',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SceneScheduleSummary(scene: widget.item.scene),
            const SizedBox(height: 8),
            Text(
              '${widget.day.title} · ${widget.day.totalMinutes}/${widget.day.maxMinutes} phút',
              style: const TextStyle(
                color: CineXPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ScheduleTimeField(
                    controller: _start,
                    label: 'Bắt đầu',
                    onPick: () => _pickTime(_start),
                    validator: (_) =>
                        _timeRangeValidator(_start.text, _end.text),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScheduleTimeField(
                    controller: _end,
                    label: 'Kết thúc',
                    onPick: () => _pickTime(_end),
                    validator: (_) =>
                        _timeRangeValidator(_start.text, _end.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _start.clear();
                          _end.clear();
                        }),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Bỏ giờ quay'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Cập nhật giờ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _clockToMinutes(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _formatClock(picked.hour * 60 + picked.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final ok = await provider.updateShootingDaySceneTime(
      widget.day.id,
      widget.item.scene.id,
      plannedStartTime: _emptyToNull(_start.text),
      plannedEndTime: _emptyToNull(_end.text),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      context,
      ok ? 'Đã cập nhật giờ quay' : provider.error ?? 'Không thể cập nhật giờ',
    );
    if (ok) Navigator.pop(context, true);
  }
}

class _SceneScheduleSummary extends StatelessWidget {
  const _SceneScheduleSummary({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CineXPalette.primary.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.sceneHeading,
              style: const TextStyle(
                color: CineXPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${scene.shootingLocationLabel} · '
              '${scene.estimatedDurationMinutes} phút',
              style: const TextStyle(color: CineXPalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTimeField extends StatelessWidget {
  const _ScheduleTimeField({
    required this.controller,
    required this.label,
    required this.onPick,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      validator: validator,
      decoration: InputDecoration(
        labelText: '$label (HH:mm)',
        suffixIcon: IconButton(
          tooltip: 'Chọn giờ',
          onPressed: onPick,
          icon: const Icon(Icons.access_time_rounded),
        ),
      ),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final dashboard = provider.dashboard;
    if (dashboard == null) return const LoadingView();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        const _SectionToolbar(title: 'Phân tích', actions: []),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _MetricTile(
                label: 'Hồi',
                value: '${dashboard.totalActs}',
                icon: Icons.view_column_rounded),
            _MetricTile(
                label: 'Cảnh',
                value: '${dashboard.totalScenes}',
                icon: Icons.movie_creation_rounded),
            _MetricTile(
                label: 'Tài nguyên',
                value: '${dashboard.totalResources}',
                icon: Icons.inventory_2_rounded),
            _MetricTile(
                label: 'Ngày quay',
                value: '${dashboard.totalShootingDays}',
                icon: Icons.calendar_month_rounded),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          child: SizedBox(
            height: 210,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                sections: [
                  PieChartSectionData(
                    value: dashboard.todoScenes.toDouble(),
                    title: 'Cần viết',
                    color: CineXPalette.textSecondary,
                  ),
                  PieChartSectionData(
                    value: dashboard.inProgressScenes.toDouble(),
                    title: 'Đang viết',
                    color: CineXPalette.warning,
                  ),
                  PieChartSectionData(
                    value: dashboard.doneScenes.toDouble(),
                    title: 'Xong',
                    color: CineXPalette.success,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tần suất nhân vật',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: CineXPalette.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              if (provider.characterFrequency.isEmpty)
                const _MutedText('Chưa có liên kết nhân vật - cảnh.')
              else
                ...provider.characterFrequency.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    trailing: _Badge(label: '${item.sceneCount} cảnh'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(icon, color: CineXPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CineXPalette.textPrimary,
                      ),
                ),
                Text(label,
                    style: const TextStyle(color: CineXPalette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictPanel extends StatelessWidget {
  const _ConflictPanel({required this.conflicts});

  final List<ScheduleConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: CineXPalette.warning),
              SizedBox(width: 8),
              Text(
                'Xung đột lịch quay',
                style: TextStyle(
                  color: CineXPalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...conflicts.take(5).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    item.message,
                    style: TextStyle(
                      color: item.blocking
                          ? CineXPalette.danger
                          : CineXPalette.warning,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: CineXPalette.textPrimary,
                  ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.primary.withAlpha(34),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: CineXPalette.primary.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: CineXPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: CineXPalette.textSecondary));
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showActSheet(BuildContext context) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: const _ActSheet(),
    ),
  );
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
    _order = TextEditingController(
      text: '${context.read<WorkspaceProvider>().acts.length + 1}',
    );
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
      title: 'Tạo hồi',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              validator: ActValidators.title,
              decoration: const InputDecoration(labelText: 'Tiêu đề hồi'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              validator: ActValidators.sequenceOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thứ tự'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<WorkspaceProvider>().createAct(
          _title.text.trim(),
          int.parse(_order.text.trim()),
          description: _emptyToNull(_description.text),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
        context,
        ok
            ? 'Đã lưu hồi'
            : context.read<WorkspaceProvider>().error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showCharacterSheet(
  BuildContext context, {
  StoryCharacter? character,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _CharacterSheet(character: character),
    ),
  );
}

class _CharacterSheet extends StatefulWidget {
  const _CharacterSheet({this.character});

  final StoryCharacter? character;

  @override
  State<_CharacterSheet> createState() => _CharacterSheetState();
}

class _CharacterSheetState extends State<_CharacterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _psychology = TextEditingController();
  final _appearance = TextEditingController();
  final _imageStorage = const ImageStorageService();
  String _role = 'MAIN';
  XFile? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final character = widget.character;
    if (character != null) {
      _name.text = character.name;
      _role = character.roleType;
      _psychology.text = character.psychologicalDescription ?? '';
      _appearance.text = character.appearanceDescription ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _psychology.dispose();
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.character?.imagePath;
    return _SheetFrame(
      title: widget.character == null ? 'Tạo nhân vật' : 'Sửa nhân vật',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 150,
                child: _pickedImage == null
                    ? SafeLocalImage(path: currentPath)
                    : SafeLocalImage(path: _pickedImage!.path),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (!mounted) return;
                      setState(() => _pickedImage = file);
                    },
              icon: const Icon(Icons.image_rounded),
              label: const Text('Chọn ảnh'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              validator: CharacterValidators.name,
              decoration: const InputDecoration(labelText: 'Tên'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              validator: CharacterValidators.roleType,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: CharacterValidators.validRoleTypes
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(characterRoleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _psychology,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Tâm lý'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _appearance,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ngoại hình'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Lưu'),
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
    final character = widget.character;
    String? imagePath;
    var ok = false;
    try {
      if (_pickedImage != null) {
        imagePath = await _imageStorage.copyPickedImage(
          _pickedImage!,
          folder: 'characters',
        );
      }
      if (!mounted) {
        if (imagePath != null) await _imageStorage.deleteIfAppOwned(imagePath);
        return;
      }
      ok = character == null
          ? await provider.createCharacter(
              _name.text.trim(),
              _role,
              psychologicalDescription: _emptyToNull(_psychology.text),
              appearanceDescription: _emptyToNull(_appearance.text),
              imagePath: imagePath,
            )
          : await provider.updateCharacter(
              character.id,
              name: _name.text.trim(),
              roleType: _role,
              psychologicalDescription: _emptyToNull(_psychology.text),
              appearanceDescription: _emptyToNull(_appearance.text),
              imagePath: imagePath,
            );
      if (imagePath != null) {
        if (ok) {
          final oldPath = character?.imagePath;
          if (oldPath != null && oldPath.isNotEmpty) {
            await _imageStorage.deleteIfAppOwned(oldPath);
          }
        } else {
          await _imageStorage.deleteIfAppOwned(imagePath);
        }
      }
    } catch (ex) {
      if (imagePath != null) {
        await _imageStorage.deleteIfAppOwned(imagePath);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, ex.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(context, ok ? 'Đã lưu nhân vật' : provider.error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showStoryLocationSheet(
  BuildContext context, {
  StoryLocation? location,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _StoryLocationSheet(location: location),
    ),
  );
}

class _StoryLocationSheet extends StatefulWidget {
  const _StoryLocationSheet({this.location});

  final StoryLocation? location;

  @override
  State<_StoryLocationSheet> createState() => _StoryLocationSheetState();
}

class _StoryLocationSheetState extends State<_StoryLocationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    if (location != null) {
      _name.text = location.name;
      _description.text = location.description ?? '';
      _notes.text = location.notes ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title:
          widget.location == null ? 'Bối cảnh truyện' : 'Sửa bối cảnh truyện',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              validator: LocationValidators.storyLocationName,
              decoration: const InputDecoration(labelText: 'Tên'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Lưu'),
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
    final location = widget.location;
    final ok = location == null
        ? await provider.createStoryLocation(
            _name.text.trim(),
            description: _emptyToNull(_description.text),
            notes: _emptyToNull(_notes.text),
          )
        : await provider.updateStoryLocation(
            location.id,
            name: _name.text.trim(),
            description: _emptyToNull(_description.text),
            notes: _emptyToNull(_notes.text),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(context, ok ? 'Đã lưu bối cảnh' : provider.error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showShootingLocationSheet(
  BuildContext context, {
  ShootingLocation? location,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ShootingLocationSheet(location: location),
    ),
  );
}

class _ShootingLocationSheet extends StatefulWidget {
  const _ShootingLocationSheet({this.location});

  final ShootingLocation? location;

  @override
  State<_ShootingLocationSheet> createState() => _ShootingLocationSheetState();
}

class _ShootingLocationSheetState extends State<_ShootingLocationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _notes = TextEditingController();
  bool _int = true;
  bool _ext = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    if (location != null) {
      _name.text = location.name;
      _address.text = location.address;
      _city.text = location.provinceCity ?? '';
      _district.text = location.district ?? '';
      _lat.text = location.latitude?.toString() ?? '';
      _lng.text = location.longitude?.toString() ?? '';
      _contact.text = location.contactName ?? '';
      _phone.text = location.contactPhone ?? '';
      _from.text = location.availableFromTime ?? '';
      _to.text = location.availableToTime ?? '';
      _notes.text = location.notes ?? '';
      _int = location.supportsInterior;
      _ext = location.supportsExterior;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _city,
      _district,
      _lat,
      _lng,
      _contact,
      _phone,
      _from,
      _to,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.location == null ? 'Địa điểm quay' : 'Sửa địa điểm quay',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              validator: LocationValidators.shootingLocationName,
              decoration: const InputDecoration(labelText: 'Tên'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              validator: LocationValidators.shootingAddress,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _city,
                        decoration:
                            const InputDecoration(labelText: 'Thành phố'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        controller: _district,
                        decoration:
                            const InputDecoration(labelText: 'Quận/huyện'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    validator: (value) =>
                        FormValidators.optionalLatitude(value, _lng.text),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Vĩ độ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    validator: (value) =>
                        FormValidators.optionalLongitude(value, _lat.text),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kinh độ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: CheckboxListTile(
                        value: _int,
                        onChanged: (value) =>
                            setState(() => _int = value ?? true),
                        title: const Text('Nội cảnh'))),
                Expanded(
                    child: CheckboxListTile(
                        value: _ext,
                        onChanged: (value) =>
                            setState(() => _ext = value ?? true),
                        title: const Text('Ngoại cảnh'))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Người liên hệ')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              validator: FormValidators.optionalPhone,
              decoration:
                  const InputDecoration(labelText: 'Số điện thoại liên hệ'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _from,
                        decoration: const InputDecoration(
                            labelText: 'Có thể dùng từ HH:mm'))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _to,
                    validator: (_) =>
                        FormValidators.timeOrder(_from.text, _to.text),
                    decoration: const InputDecoration(
                        labelText: 'Có thể dùng đến HH:mm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ghi chú')),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Lưu'),
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
    final body = {
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'provinceCity': _emptyToNull(_city.text),
      'district': _emptyToNull(_district.text),
      'latitude': _emptyToNull(_lat.text),
      'longitude': _emptyToNull(_lng.text),
      'contactName': _emptyToNull(_contact.text),
      'contactPhone': _emptyToNull(_phone.text),
      'supportsInterior': _int,
      'supportsExterior': _ext,
      'availableFromTime': _emptyToNull(_from.text),
      'availableToTime': _emptyToNull(_to.text),
      'notes': _emptyToNull(_notes.text),
    };
    final location = widget.location;
    final ok = location == null
        ? await provider.createShootingLocation(body)
        : await provider.updateShootingLocation(location.id, body);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(context,
        ok ? 'Đã lưu địa điểm quay' : provider.error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showResourceSheet(
  BuildContext context, {
  FilmResource? resource,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ResourceSheet(resource: resource),
    ),
  );
}

class _ResourceSheet extends StatefulWidget {
  const _ResourceSheet({this.resource});

  final FilmResource? resource;

  @override
  State<_ResourceSheet> createState() => _ResourceSheetState();
}

class _ResourceSheetState extends State<_ResourceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController();
  final _status = TextEditingController(text: 'AVAILABLE');
  final _notes = TextEditingController();
  String _type = 'PROP';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final resource = widget.resource;
    if (resource != null) {
      _name.text = resource.name;
      _quantity.text = '${resource.quantityTotal}';
      _unit.text = resource.unit ?? '';
      _status.text = resource.status ?? 'AVAILABLE';
      _notes.text = resource.notes ?? '';
      _type = resource.resourceType;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _status.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _resourceStatusValue {
    final status = _status.text.trim();
    const supported = {
      'AVAILABLE',
      'RESERVED',
      'IN_USE',
      'DAMAGED',
      'UNAVAILABLE',
    };
    return supported.contains(status) ? status : 'AVAILABLE';
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.resource == null ? 'Tài nguyên phim' : 'Sửa tài nguyên',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
                controller: _name,
                validator: ResourceValidators.name,
                decoration: const InputDecoration(labelText: 'Tên')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              validator: ResourceValidators.type,
              decoration: const InputDecoration(labelText: 'Loại'),
              items: ResourceValidators.validTypes
                  .map((type) => DropdownMenuItem(
                      value: type, child: Text(resourceTypeLabel(type))))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _quantity,
                validator: ResourceValidators.quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số lượng')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Đơn vị')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _resourceStatusValue,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: const [
                'AVAILABLE',
                'RESERVED',
                'IN_USE',
                'DAMAGED',
                'UNAVAILABLE',
              ]
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(resourceStatusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _status.text = value ?? 'AVAILABLE'),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ghi chú')),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Lưu'),
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
    final body = {
      'name': _name.text.trim(),
      'resourceType': _type,
      'quantityTotal': int.parse(_quantity.text.trim()),
      'unit': _emptyToNull(_unit.text),
      'status': _emptyToNull(_status.text),
      'notes': _emptyToNull(_notes.text),
    };
    final resource = widget.resource;
    final ok = resource == null
        ? await provider.createResource(body)
        : await provider.updateResource(resource.id, body);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
        context, ok ? 'Đã lưu tài nguyên' : provider.error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showSceneSheet(BuildContext context) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: const _SceneSheet(),
    ),
  );
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
  final _minutes = TextEditingController(text: '30');
  late final TextEditingController _number;
  int? _actId;
  int? _storyLocationId;
  int? _shootingLocationId;
  String _settingType = 'INT';
  String _timeOfDay = 'DAY';
  String _writingStatus = 'TODO';
  String _productionStatus = 'NOT_READY';
  int _priority = 3;
  final Set<int> _characters = {};
  final Map<int, int> _resourceQuantities = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WorkspaceProvider>();
    _number = TextEditingController(text: '${provider.scenes.length + 1}');
    _actId = provider.acts.isEmpty ? null : provider.acts.first.id;
    _storyLocationId = provider.storyLocations.isEmpty
        ? null
        : provider.storyLocations.first.id;
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
    if (provider.acts.isEmpty || provider.storyLocations.isEmpty) {
      return _SheetFrame(
        title: 'Tạo cảnh',
        child: EmptyView(
          title: 'Cần thiết lập thêm',
          message: provider.acts.isEmpty
              ? 'Tạo một hồi trước khi thêm cảnh.'
              : 'Tạo một bối cảnh truyện trước khi thêm cảnh.',
          icon: Icons.tune_rounded,
        ),
      );
    }
    if (!provider.acts.any((act) => act.id == _actId)) {
      _actId = provider.acts.first.id;
    }
    if (!provider.storyLocations
        .any((location) => location.id == _storyLocationId)) {
      _storyLocationId = provider.storyLocations.first.id;
    }
    if (_shootingLocationId != null &&
        !provider.shootingLocations
            .any((location) => location.id == _shootingLocationId)) {
      _shootingLocationId = null;
    }
    return _SheetFrame(
      title: 'Tạo cảnh',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
                controller: _number,
                validator: SceneValidators.sceneNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số cảnh')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Tiêu đề')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _summary,
                validator: (_) =>
                    SceneValidators.titleOrSummary(_title.text, _summary.text),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Tóm tắt')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _actId,
              decoration: const InputDecoration(labelText: 'Hồi'),
              items: provider.acts
                  .map((act) => DropdownMenuItem<int>(
                        value: act.id,
                        child: Text(act.title),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _actId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _storyLocationId,
              decoration: const InputDecoration(labelText: 'Bối cảnh truyện'),
              items: provider.storyLocations
                  .map((location) => DropdownMenuItem<int>(
                        value: location.id,
                        child: Text(location.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _storyLocationId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _shootingLocationId,
              decoration:
                  const InputDecoration(labelText: 'Địa điểm quay thực tế'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Chưa gán')),
                ...provider.shootingLocations.map(
                  (location) => DropdownMenuItem<int?>(
                    value: location.id,
                    child: Text('${location.name}, ${location.address}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _shootingLocationId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _settingType,
                    validator: SceneValidators.settingType,
                    decoration: const InputDecoration(labelText: 'Bối cảnh'),
                    items: const ['INT', 'EXT']
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(settingTypeLabel(value))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _settingType = value ?? _settingType),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _timeOfDay,
                    validator: SceneValidators.timeOfDay,
                    decoration: const InputDecoration(labelText: 'Thời điểm'),
                    items: const ['DAY', 'NIGHT']
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(timeOfDayLabel(value))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _timeOfDay = value ?? _timeOfDay),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _minutes,
                validator: SceneValidators.estimatedDuration,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Số phút ước tính')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _writingStatus,
              decoration: const InputDecoration(labelText: 'Trạng thái viết'),
              items: SceneValidators.writingStatuses
                  .map((status) => DropdownMenuItem(
                      value: status, child: Text(sceneStatusLabel(status))))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _writingStatus = value ?? _writingStatus),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _productionStatus,
              decoration:
                  const InputDecoration(labelText: 'Trạng thái sản xuất'),
              items: SceneValidators.productionStatuses
                  .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(productionStatusLabel(status))))
                  .toList(),
              onChanged: (value) => setState(
                  () => _productionStatus = value ?? _productionStatus),
            ),
            const SizedBox(height: 12),
            Stepper(
              physics: const NeverScrollableScrollPhysics(),
              currentStep: _priority - 1,
              controlsBuilder: (_, __) => const SizedBox.shrink(),
              onStepTapped: (step) => setState(() => _priority = step + 1),
              steps: List.generate(
                  5,
                  (index) => Step(
                      title: Text('Ưu tiên ${index + 1}'),
                      content: const SizedBox.shrink())),
            ),
            const SizedBox(height: 12),
            const _MutedText('Nhân vật'),
            Wrap(
              spacing: 8,
              children: provider.characters
                  .map((character) => FilterChip(
                      label: Text(character.name),
                      selected: _characters.contains(character.id),
                      onSelected: (selected) => setState(() => selected
                          ? _characters.add(character.id)
                          : _characters.remove(character.id))))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const _MutedText('Tài nguyên'),
            ...provider.resources.map(
              (resource) => CheckboxListTile(
                value: _resourceQuantities.containsKey(resource.id),
                title: Text(
                    '${resource.name} (${resource.quantityTotal} ${resource.unit ?? ''})'),
                subtitle: _resourceQuantities.containsKey(resource.id)
                    ? TextFormField(
                        initialValue: '${_resourceQuantities[resource.id]}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Số lượng cần dùng'),
                        validator: (value) =>
                            ResourceValidators.requiredQuantity(
                          requiredQuantity:
                              int.tryParse((value ?? '').trim()) ?? 0,
                          totalQuantity: resource.quantityTotal,
                        ),
                        onChanged: (value) => _resourceQuantities[resource.id] =
                            int.tryParse(value) ?? 1,
                      )
                    : null,
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _resourceQuantities[resource.id] = 1;
                  } else {
                    _resourceQuantities.remove(resource.id);
                  }
                }),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Lưu cảnh'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final actId = _actId;
    final storyLocationId = _storyLocationId;
    if (actId == null || storyLocationId == null) return;
    setState(() => _saving = true);
    final ok = await context.read<WorkspaceProvider>().createScene(
          sceneNumber: int.parse(_number.text.trim()),
          actId: actId,
          locationId: storyLocationId,
          plannedShootingLocationId: _shootingLocationId,
          summary: _summary.text.trim(),
          status: _writingStatus,
          title: _emptyToNull(_title.text),
          settingType: _settingType,
          timeOfDay: _timeOfDay,
          estimatedMinutes: int.parse(_minutes.text.trim()),
          priority: _priority,
          productionStatus: _productionStatus,
          characterIds: _characters.toList(),
          resourceRequirements: _resourceQuantities.entries
              .map((entry) =>
                  {'resourceId': entry.key, 'requiredQuantity': entry.value})
              .toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
        context,
        ok
            ? 'Đã lưu cảnh'
            : context.read<WorkspaceProvider>().error ?? 'Không thể lưu');
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showShootingDaySheet(
  BuildContext context, {
  DateTime? initialDate,
  ShootingDay? day,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ShootingDaySheet(initialDate: initialDate, day: day),
    ),
  );
}

class _ShootingDaySheet extends StatefulWidget {
  const _ShootingDaySheet({this.initialDate, this.day});

  final DateTime? initialDate;
  final ShootingDay? day;

  @override
  State<_ShootingDaySheet> createState() => _ShootingDaySheetState();
}

class _ShootingDaySheetState extends State<_ShootingDaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  final _max = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WorkspaceProvider>();
    final day = widget.day;
    _title = TextEditingController(text: day?.title ?? 'Ngày quay');
    _date = day?.shootingDate ?? widget.initialDate ?? provider.selectedDate;
    _max.text =
        '${day?.maxMinutes ?? provider.project.maxShootingMinutesPerDay}';
    _notes.text = day?.notes ?? '';
    _title.addListener(_refreshDetailPreview);
    _max.addListener(_refreshDetailPreview);
    _notes.addListener(_refreshDetailPreview);
  }

  @override
  void dispose() {
    _title.removeListener(_refreshDetailPreview);
    _max.removeListener(_refreshDetailPreview);
    _notes.removeListener(_refreshDetailPreview);
    _title.dispose();
    _max.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.day == null ? 'Tạo ngày quay' : 'Sửa ngày quay',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
                controller: _title,
                validator: (value) =>
                    FormValidators.requiredTrimmed(value, 'Tiêu đề'),
                decoration: const InputDecoration(labelText: 'Tiêu đề')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _max,
                validator: ShootingDayValidators.maxMinutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số phút tối đa')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (!mounted) return;
                setState(() => _date = date ?? _date);
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(_date == null
                  ? 'Chọn ngày'
                  : _date!.toIso8601String().split('T').first),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ghi chú')),
            const SizedBox(height: 14),
            _ShootingDayFormDetail(
              day: widget.day,
              date: _date,
              title: _title.text,
              maxMinutesText: _max.text,
              notes: _notes.text,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(widget.day == null ? 'Lưu' : 'Cập nhật')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _date == null) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final day = widget.day;
    final ok = day == null
        ? await provider.createShootingDay(
            date: _date!,
            title: _title.text.trim(),
            maxMinutes: int.parse(_max.text.trim()),
            notes: _emptyToNull(_notes.text),
          )
        : await provider.updateShootingDay(
            day.id,
            date: _date!,
            title: _title.text.trim(),
            maxMinutes: int.parse(_max.text.trim()),
            notes: _emptyToNull(_notes.text),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      context,
      ok
          ? (day == null ? 'Đã lưu ngày quay' : 'Đã cập nhật ngày quay')
          : provider.error ?? 'Không thể lưu',
    );
    if (ok) Navigator.pop(context, true);
  }

  void _refreshDetailPreview() {
    if (mounted) setState(() {});
  }
}

class _ShootingDayFormDetail extends StatelessWidget {
  const _ShootingDayFormDetail({
    required this.day,
    required this.date,
    required this.title,
    required this.maxMinutesText,
    required this.notes,
  });

  final ShootingDay? day;
  final DateTime? date;
  final String title;
  final String maxMinutesText;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final effectiveTitle = title.trim().isEmpty ? 'Ngày quay' : title.trim();
    final maxMinutes =
        int.tryParse(maxMinutesText.trim()) ?? day?.maxMinutes ?? 0;
    final totalMinutes = day?.totalMinutes ?? 0;
    final scenes = day?.scenes ?? const <ShootingDayScene>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(160),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  color: CineXPalette.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chi tiết ngày quay',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: CineXPalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _Badge(label: shootingDayStatusLabel(day?.status ?? 'DRAFT')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              effectiveTitle,
              style: const TextStyle(
                color: CineXPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date == null
                  ? 'Chưa chọn ngày'
                  : localizations.formatFullDate(date!),
              style: const TextStyle(color: CineXPalette.textSecondary),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: maxMinutes <= 0
                  ? 0
                  : (totalMinutes / maxMinutes).clamp(0.0, 1.0),
            ),
            const SizedBox(height: 6),
            Text(
              '$totalMinutes/$maxMinutes phút',
              style: const TextStyle(color: CineXPalette.textSecondary),
            ),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes.trim(),
                style: const TextStyle(color: CineXPalette.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            if (scenes.isEmpty)
              const _MutedText('Chưa có cảnh trong ngày quay này.')
            else
              ...scenes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.movie_creation_outlined,
                        size: 18,
                        color: CineXPalette.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.scene.sceneHeading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.plannedStartTime ?? '--:--'} - '
                        '${item.plannedEndTime ?? '--:--'}',
                        style: const TextStyle(
                          color: CineXPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: CineXPalette.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> _exportPdf(BuildContext context) async {
  final bytes = await context.read<WorkspaceProvider>().exportPdf();
  if (!context.mounted) return;
  if (bytes == null) {
    _snack(context, 'Không thể xuất PDF');
    return;
  }
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateKey(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

int _nextAvailableMinute(ShootingDay day) {
  var cursor = 8 * 60;
  final scenes = [...day.scenes]
    ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
  for (final item in scenes) {
    final end = _clockToMinutes(item.plannedEndTime);
    if (end != null && end > cursor) {
      cursor = end;
    } else {
      cursor += item.scene.estimatedDurationMinutes;
    }
  }
  return cursor;
}

int _suggestedMinuteForScene(ShootingDay day, ShootingDayScene target) {
  var cursor = 8 * 60;
  final scenes = [...day.scenes]
    ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
  for (final item in scenes) {
    if (item.scene.id == target.scene.id) return cursor;
    final end = _clockToMinutes(item.plannedEndTime);
    if (end != null && end > cursor) {
      cursor = end;
    } else {
      cursor += item.scene.estimatedDurationMinutes;
    }
  }
  return cursor;
}

String? _timeRangeValidator(String start, String end) {
  final hasStart = start.trim().isNotEmpty;
  final hasEnd = end.trim().isNotEmpty;
  if (!hasStart && !hasEnd) return null;
  if (hasStart != hasEnd) return 'Nhập đủ giờ bắt đầu và kết thúc';
  final from = _clockToMinutes(start);
  final to = _clockToMinutes(end);
  if (from == null || to == null) return 'Giờ phải theo định dạng HH:mm';
  return to <= from ? 'Giờ kết thúc phải sau giờ bắt đầu' : null;
}

int? _clockToMinutes(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

bool _isValidClockMinute(int minutes) {
  return minutes >= 0 && minutes < 24 * 60;
}

String _formatClock(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

Color _shootingDayStatusColor(String status) {
  return switch (status) {
    'CONFIRMED' => CineXPalette.accent,
    'IN_PROGRESS' => CineXPalette.warning,
    'COMPLETED' => CineXPalette.success,
    'CANCELLED' => CineXPalette.danger,
    _ => CineXPalette.primary,
  };
}

String? _emptyToNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
