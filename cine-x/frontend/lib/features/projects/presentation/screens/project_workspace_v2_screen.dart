import 'dart:io';

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

const _projectMemberRoles = [
  'SCREENWRITER',
  'PRODUCER',
  'ASSISTANT_DIRECTOR',
  'CREW',
  'VIEWER',
];

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
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts_rounded),
      label: 'Thành viên',
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
      const _MembersPage(),
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
                tooltip: 'Quay lại',
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
          Icons.add_box_rounded,
          'Tài nguyên mới',
          ProjectPermission.manageResources,
          () => _showResourceSheet(context),
        ),
      2 => (
          Icons.event_available_rounded,
          'Ngày quay mới',
          ProjectPermission.manageSchedule,
          () => _showShootingDaySheet(context),
        ),
      3 => (
          Icons.person_add_alt_rounded,
          'Thành viên mới',
          ProjectPermission.manageMembers,
          () => _showMemberSheet(context),
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
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.view_column_rounded), text: 'Quản lý hồi'),
              Tab(icon: Icon(Icons.movie_creation_rounded), text: 'Quản lý cảnh'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ActsList(),
                _ScenesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActsList extends StatelessWidget {
  const _ActsList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    if (provider.acts.isEmpty) {
      return EmptyView(
        title: 'Chưa có hồi',
        message: 'Tạo hồi trước khi chia cảnh cho kịch bản.',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Hồi kịch bản',
          actions: [
            _ToolbarAction(
              icon: Icons.playlist_add_rounded,
              tooltip: 'Tạo hồi',
              enabled: provider.can(ProjectPermission.manageStory),
              onPressed: () => _showActSheet(context),
            ),
          ],
        ),
        ...provider.acts.map((act) => _ActManagementCard(act: act)),
      ],
    );
  }
}

class _ActManagementCard extends StatelessWidget {
  const _ActManagementCard({required this.act});

  final Act act;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final canEdit = provider.can(ProjectPermission.manageStory);
    final actScenes = provider.scenes
        .where((scene) => scene.actId == act.id)
        .toList()
      ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
    final sceneCount = actScenes.length;
    final description = (act.description ?? '').trim();
    return _Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        leading: CircleAvatar(
          backgroundColor: CineXPalette.primary.withAlpha(32),
          foregroundColor: CineXPalette.primary,
          child: Text(
            '${act.sequenceOrder}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(act.title),
        subtitle: Text('$sceneCount cảnh'),
        children: [
          if (description.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: const TextStyle(color: CineXPalette.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (actScenes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MutedText('Chưa có phân cảnh nào trong hồi này.'),
              ),
            )
          else
            ...actScenes.map(
              (scene) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: CineXPalette.primary.withAlpha(16),
                  title: Text(scene.sceneHeading),
                  subtitle: Text(
                    [
                      sceneStatusLabel(scene.writingStatus),
                      if (scene.summary.trim().isNotEmpty) scene.summary,
                    ].join(' - '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: canEdit
                      ? IconButton(
                          tooltip: 'Sửa cảnh',
                          onPressed: () => _showSceneSheet(
                            context,
                            scene: scene,
                          ),
                          icon: const Icon(Icons.edit_rounded),
                        )
                      : null,
                  onTap: canEdit
                      ? () => _showSceneSheet(context, scene: scene)
                      : null,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    canEdit ? () => _showActSheet(context, act: act) : null,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Sửa hồi'),
              ),
              OutlinedButton.icon(
                onPressed: canEdit
                    ? () async {
                        final confirmed = await _confirm(
                          context,
                          title: 'Xóa hồi?',
                          message:
                              'Hồi này và $sceneCount cảnh bên trong sẽ bị xóa, đồng thời gỡ khỏi lịch quay.',
                        );
                        if (!context.mounted || !confirmed) return;
                        final ok = await provider.deleteAct(act);
                        if (context.mounted) {
                          _snack(
                            context,
                            ok
                                ? 'Đã xóa hồi'
                                : provider.error ?? 'Không thể xóa hồi',
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xóa hồi'),
              ),
              FilledButton.icon(
                onPressed: canEdit
                    ? () => _showSceneSheet(context, initialActId: act.id)
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm phân cảnh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenesList extends StatefulWidget {
  const _ScenesList();

  @override
  State<_ScenesList> createState() => _ScenesListState();
}

class _ScenesListState extends State<_ScenesList> {
  final _search = TextEditingController();
  int? _actId;
  int? _characterId;
  int? _locationId;
  String? _settingType;
  String? _timeOfDay;
  String? _writingStatus;
  String? _productionStatus;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    if (_actId != null && !provider.acts.any((act) => act.id == _actId)) {
      _actId = null;
    }
    if (_characterId != null &&
        !provider.characters.any((character) => character.id == _characterId)) {
      _characterId = null;
    }
    if (_locationId != null &&
        !provider.storyLocations
            .any((location) => location.id == _locationId)) {
      _locationId = null;
    }
    final keyword = _search.text.trim().toLowerCase();
    final scenes = provider.scenes.where((scene) {
      final byKeyword = keyword.isEmpty ||
          [
            scene.sceneHeading,
            scene.title ?? '',
            scene.summary,
            scene.actTitle,
            scene.storyLocationName,
          ].any((value) => value.toLowerCase().contains(keyword));
      final byAct = _actId == null || scene.actId == _actId;
      final byCharacter = _characterId == null ||
          scene.characters.any((character) => character.id == _characterId);
      final byLocation =
          _locationId == null || scene.storyLocationId == _locationId;
      final bySetting =
          _settingType == null || scene.settingType == _settingType;
      final byTime = _timeOfDay == null || scene.timeOfDay == _timeOfDay;
      final byWriting = _writingStatus == null ||
          scene.writingStatus == _writingStatus;
      final byProduction = _productionStatus == null ||
          scene.productionStatus == _productionStatus;
      return byKeyword &&
          byAct &&
          byCharacter &&
          byLocation &&
          bySetting &&
          byTime &&
          byWriting &&
          byProduction;
    }).toList()
      ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
    final hasFilters = keyword.isNotEmpty ||
        _actId != null ||
        _characterId != null ||
        _locationId != null ||
        _settingType != null ||
        _timeOfDay != null ||
        _writingStatus != null ||
        _productionStatus != null;

    if (provider.scenes.isEmpty) {
      return EmptyView(
        title: 'Chưa có cảnh',
        message: 'Thêm cảnh sau khi đã tạo hồi và bối cảnh truyện.',
        icon: Icons.movie_creation_outlined,
        action: FilledButton.icon(
          onPressed: provider.can(ProjectPermission.manageStory)
              ? () => _showSceneSheet(context)
              : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tạo cảnh'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Cảnh kịch bản (${scenes.length})',
          actions: [
            _ToolbarAction(
              icon: Icons.add_rounded,
              tooltip: 'Tạo cảnh',
              enabled: provider.can(ProjectPermission.manageStory),
              onPressed: () => _showSceneSheet(context),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final searchField = TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tìm theo cảnh, tiêu đề, tóm tắt',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final filters = <Widget>[
              DropdownButtonFormField<int?>(
                initialValue: _actId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Hồi'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...provider.acts.map(
                    (act) => DropdownMenuItem<int?>(
                      value: act.id,
                      child: _DropdownText(act.title),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _actId = value),
              ),
              DropdownButtonFormField<int?>(
                initialValue: _characterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhân vật'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...provider.characters.map(
                    (character) => DropdownMenuItem<int?>(
                      value: character.id,
                      child: _DropdownText(character.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _characterId = value),
              ),
              DropdownButtonFormField<int?>(
                initialValue: _locationId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bối cảnh truyện'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...provider.storyLocations.map(
                    (location) => DropdownMenuItem<int?>(
                      value: location.id,
                      child: _DropdownText(location.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _locationId = value),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _settingType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nội / ngoại'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...SceneValidators.settingTypes.map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: _DropdownText(settingTypeLabel(value)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _settingType = value),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _timeOfDay,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ngày / đêm'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...SceneValidators.timeOfDayValues.map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: _DropdownText(timeOfDayLabel(value)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _timeOfDay = value),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _writingStatus,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Trạng thái viết'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...SceneValidators.writingStatuses.map(
                    (status) => DropdownMenuItem<String?>(
                      value: status,
                      child: _DropdownText(sceneStatusLabel(status)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _writingStatus = value),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _productionStatus,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Trạng thái sản xuất'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: _DropdownText('Tất cả'),
                  ),
                  ...SceneValidators.productionStatuses.map(
                    (status) => DropdownMenuItem<String?>(
                      value: status,
                      child: _DropdownText(productionStatusLabel(status)),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _productionStatus = value),
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                if (compact)
                  ...[
                    for (final filter in filters) ...[
                      filter,
                      const SizedBox(height: 10),
                    ],
                  ]
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final filter in filters)
                        SizedBox(width: 220, child: filter),
                    ],
                  ),
                if (hasFilters)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Xóa lọc'),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (scenes.isEmpty)
          const _Panel(child: _MutedText('Không có cảnh theo bộ lọc này.'))
        else
          ...scenes.map((scene) => _SceneCard(scene: scene)),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _actId = null;
      _characterId = null;
      _locationId = null;
      _settingType = null;
      _timeOfDay = null;
      _writingStatus = null;
      _productionStatus = null;
    });
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
                    if (value == 'edit') {
                      _showSceneSheet(context, scene: scene);
                      return;
                    } else if (value == 'delete') {
                      final confirmed = await _confirm(
                        context,
                        title: 'Xóa cảnh?',
                        message:
                            'Cảnh và các liên kết lịch quay, nhân vật, tài nguyên sẽ bị xóa.',
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
                    PopupMenuItem(value: 'edit', child: Text('Sửa cảnh')),
                    PopupMenuItem(
                        value: 'ready', child: Text('Sẵn sàng lên lịch')),
                    PopupMenuItem(
                        value: 'done', child: Text('Đánh dấu viết xong')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa cảnh')),
                  ],
                ),
              ],
            ),
            if (scene.title != null) ...[
              const SizedBox(height: 4),
              Text(scene.title!,
                  style: const TextStyle(color: CineXPalette.accent)),
            ],
            if (scene.characters.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SceneAvatars(characters: scene.characters),
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

class _SceneAvatars extends StatelessWidget {
  const _SceneAvatars({required this.characters});

  final List<SceneCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final visible = characters.take(5).toList();
    final overflow = characters.length - visible.length;
    final width = visible.length * 24.0 + (overflow > 0 ? 36 : 8);
    return Row(
      children: [
        SizedBox(
          width: width,
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < visible.length; index++)
                Positioned(
                  left: index * 24,
                  child: Tooltip(
                    message:
                        '${visible[index].name} - ${characterRoleLabel(visible[index].roleType)}',
                    child: _CharacterAvatar(
                      name: visible[index].name,
                      imageUrl: visible[index].imageUrl,
                    ),
                  ),
                ),
              if (overflow > 0)
                Positioned(
                  left: visible.length * 24,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: CineXPalette.divider,
                    child: Text(
                      '+$overflow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            characters.map((character) => character.name).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CineXPalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({
    required this.name,
    this.imageUrl,
    this.radius = 17,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = _avatarImage(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: CineXPalette.primary,
      backgroundImage: image,
      child: image == null
          ? Text(
              _initials(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius <= 14 ? 10 : 11,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
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

class _MembersPage extends StatelessWidget {
  const _MembersPage();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final members = provider.members;
    final canManage = provider.can(ProjectPermission.manageMembers);
    if (members.isEmpty) {
      return EmptyView(
        title: 'Chưa có thành viên',
        message: 'Mời biên kịch, nhà sản xuất hoặc đội quay vào dự án.',
        icon: Icons.manage_accounts_rounded,
        action: FilledButton.icon(
          onPressed: canManage ? () => _showMemberSheet(context) : null,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Thêm thành viên'),
        ),
      );
    }
    final ownerCount =
        members.where((member) => member.role == 'OWNER').length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _SectionToolbar(
          title: 'Thành viên dự án (${members.length})',
          actions: [
            _ToolbarAction(
              icon: Icons.person_add_alt_rounded,
              tooltip: 'Thêm thành viên',
              enabled: canManage,
              onPressed: () => _showMemberSheet(context),
            ),
          ],
        ),
        ...members.map(
          (member) {
            final name = member.fullName?.trim().isNotEmpty == true
                ? member.fullName!.trim()
                : member.email ?? 'Thành viên';
            final canDelete = canManage &&
                !(member.role == 'OWNER' && ownerCount <= 1);
            return _Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: CineXPalette.primary.withAlpha(36),
                  foregroundColor: CineXPalette.textPrimary,
                  child: Text(_initials(name)),
                ),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.email ?? 'Chưa có email'),
                    const SizedBox(height: 6),
                    _Badge(label: projectRoleLabel(member.role)),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Sửa vai trò',
                      onPressed: canManage
                          ? () => _showMemberSheet(context, member: member)
                          : null,
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Xóa thành viên',
                      onPressed: canDelete
                          ? () async {
                              final confirmed = await _confirm(
                                context,
                                title: 'Xóa thành viên?',
                                message:
                                    '$name sẽ không còn truy cập được dự án này.',
                              );
                              if (!context.mounted || !confirmed) return;
                              final ok = await provider.deleteMember(member);
                              if (!context.mounted) return;
                              _snack(
                                context,
                                ok
                                    ? 'Đã xóa thành viên'
                                    : provider.error ?? 'Không thể xóa',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.person_remove_rounded),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarPage extends StatefulWidget {
  const _CalendarPage();

  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
  int? _selectedDayId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkspaceProvider>();
    final selectedDateDays = provider.selectedDateDays;
    final selectedDay = _resolveSelectedDay(selectedDateDays);
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
            selectedDayId: selectedDay?.id,
            shootingDaysByDate: shootingDaysByDate,
            canManage: provider.can(ProjectPermission.manageSchedule),
            onDateSelected: (date) {
              setState(() => _selectedDayId = null);
              provider.loadCalendar(date: date);
            },
            onMonthChanged: (month) => provider.loadCalendar(date: month),
            onAddDay: (date) =>
                _showShootingDaySheet(context, initialDate: date),
            onDaySelected: (day) {
              setState(() => _selectedDayId = day.id);
              provider.loadCalendar(date: day.shootingDate);
            },
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
          canManage: provider.can(ProjectPermission.manageSchedule),
          onAdd: () => _showShootingDaySheet(context,
              initialDate: provider.selectedDate),
          onEdit: selectedDay != null
              ? () => _showShootingDaySheet(
                    context,
                    day: selectedDay,
                  )
              : null,
        ),
        const SizedBox(height: 8),
        if (selectedDateDays.length > 1)
          _ShootingDayChoiceBar(
            days: selectedDateDays,
            selectedDayId: selectedDay?.id,
            onSelected: (day) => setState(() => _selectedDayId = day.id),
          ),
        if (selectedDateDays.length > 1) const SizedBox(height: 8),
        if (selectedDay == null)
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
          _ShootingDayCard(day: selectedDay),
      ],
    );
  }

  ShootingDay? _resolveSelectedDay(List<ShootingDay> days) {
    if (days.isEmpty) return null;
    final selectedId = _selectedDayId;
    if (selectedId != null) {
      for (final day in days) {
        if (day.id == selectedId) return day;
      }
    }
    return days.first;
  }
}

class _ShootingDayChoiceBar extends StatelessWidget {
  const _ShootingDayChoiceBar({
    required this.days,
    required this.selectedDayId,
    required this.onSelected,
  });

  final List<ShootingDay> days;
  final int? selectedDayId;
  final ValueChanged<ShootingDay> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in days) ...[
            ChoiceChip(
              label: Text(day.title),
              selected: day.id == selectedDayId,
              onSelected: (_) => onSelected(day),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SelectedDateToolbar extends StatelessWidget {
  const _SelectedDateToolbar({
    required this.date,
    required this.canManage,
    required this.onAdd,
    this.onEdit,
  });

  final DateTime date;
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
          tooltip: onEdit == null ? 'Chọn một ngày quay để sửa' : 'Sửa ngày quay',
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
    required this.selectedDayId,
    required this.shootingDaysByDate,
    required this.canManage,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.onAddDay,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final int? selectedDayId;
  final Map<DateTime, List<ShootingDay>> shootingDaysByDate;
  final bool canManage;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onAddDay;
  final ValueChanged<ShootingDay> onDaySelected;

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
                  selectedDayId: selectedDayId,
                  today: _sameDate(date, DateTime.now()),
                  compact: compact,
                  canManage: canManage,
                  onSelect: () => onDateSelected(date),
                  onAdd: () => onAddDay(date),
                  onDaySelected: onDaySelected,
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
    required this.selectedDayId,
    required this.today,
    required this.compact,
    required this.canManage,
    required this.onSelect,
    required this.onAdd,
    required this.onDaySelected,
  });

  final DateTime date;
  final List<ShootingDay> days;
  final bool inMonth;
  final bool selected;
  final int? selectedDayId;
  final bool today;
  final bool compact;
  final bool canManage;
  final VoidCallback onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ShootingDay> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final visibleDays = days.take(compact ? 2 : 3).toList();
    final dateChipSize = compact ? 20.0 : 28.0;
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
                SizedBox(
                  height: dateChipSize,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: dateChipSize,
                          height: dateChipSize,
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
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (days.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: compact ? 6 : 7,
                            height: compact ? 6 : 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      else if (canManage && !compact)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
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
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: compact
                      ? _CompactCalendarMarkers(
                          days: days,
                          selectedDayId: selectedDayId,
                          onTap: onSelect,
                        )
                      : Column(
                          children: [
                            ...visibleDays.map(
                              (day) => _CalendarEventPill(
                                day: day,
                                compact: compact,
                                selected: day.id == selectedDayId,
                                onTap: () => onDaySelected(day),
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

class _CompactCalendarMarkers extends StatelessWidget {
  const _CompactCalendarMarkers({
    required this.days,
    required this.selectedDayId,
    required this.onTap,
  });

  final List<ShootingDay> days;
  final int? selectedDayId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            for (final day in days.take(4))
              Container(
                width: day.id == selectedDayId ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _shootingDayStatusColor(day.status),
                  borderRadius: BorderRadius.circular(99),
                  border: day.id == selectedDayId
                      ? Border.all(color: CineXPalette.textPrimary)
                      : null,
                ),
              ),
            if (days.length > 4)
              Text(
                '+${days.length - 4}',
                style: const TextStyle(
                  color: CineXPalette.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventPill extends StatelessWidget {
  const _CalendarEventPill({
    required this.day,
    required this.compact,
    required this.selected,
    this.onTap,
  });

  final ShootingDay day;
  final bool compact;
  final bool selected;
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
              color: selected
                  ? CineXPalette.primary.withAlpha(54)
                  : color.withAlpha(38),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: selected ? CineXPalette.primary : color.withAlpha(120),
              ),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: canEditDay
                            ? () => _showShootingDaySheet(context, day: day)
                            : null,
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Chỉnh sửa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canEditDay &&
                                provider.unscheduledScenes.isNotEmpty
                            ? () => _showShootingDaySheet(context, day: day)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm cảnh'),
                      ),
                    ],
                  ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final charts = [
              _CharacterFrequencyChart(items: provider.characterFrequency),
              _SettingRatioChart(scenes: provider.scenes),
            ];
            if (constraints.maxWidth < 760) {
              return Column(children: charts);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: charts[0]),
                const SizedBox(width: 12),
                Expanded(child: charts[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CharacterFrequencyChart extends StatelessWidget {
  const _CharacterFrequencyChart({required this.items});

  final List<CharacterFrequency> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) => item.sceneCount > 0).take(8).toList();
    final maxScenes = visible.isEmpty
        ? 1
        : visible.map((item) => item.sceneCount).reduce((a, b) => a > b ? a : b);
    final interval = maxScenes <= 4 ? 1.0 : (maxScenes / 4).ceilToDouble();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tần suất xuất hiện nhân vật',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: _MutedText('Chưa có liên kết nhân vật - cảnh.'),
              ),
            )
          else ...[
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxScenes.toDouble(),
                  minY: 0,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: CineXPalette.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > maxScenes) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: CineXPalette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (value != index ||
                              index < 0 ||
                              index >= visible.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              _initials(visible[index].name),
                              style: const TextStyle(
                                color: CineXPalette.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < visible.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: visible[index].sceneCount.toDouble(),
                            width: 22,
                            color: CineXPalette.secondary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...visible.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _CharacterAvatar(name: item.name, radius: 13),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CineXPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Badge(label: '${item.sceneCount} cảnh'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingRatioChart extends StatelessWidget {
  const _SettingRatioChart({required this.scenes});

  final List<Scene> scenes;

  @override
  Widget build(BuildContext context) {
    final interior = scenes.where((scene) => scene.settingType == 'INT').length;
    final exterior = scenes.where((scene) => scene.settingType == 'EXT').length;
    final total = interior + exterior;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tỷ lệ Nội cảnh / Ngoại cảnh',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CineXPalette.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: total == 0
                ? const Center(
                    child: _MutedText('Chưa có cảnh để thống kê.'),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 42,
                      sections: [
                        if (interior > 0)
                          PieChartSectionData(
                            value: interior.toDouble(),
                            title: _percentLabel(interior, total),
                            radius: 72,
                            color: CineXPalette.primary,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (exterior > 0)
                          PieChartSectionData(
                            value: exterior.toDouble(),
                            title: _percentLabel(exterior, total),
                            radius: 72,
                            color: CineXPalette.accent,
                            titleStyle: const TextStyle(
                              color: CineXPalette.background,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          _ChartLegendItem(
            color: CineXPalette.primary,
            label: 'Nội cảnh (INT)',
            value: '$interior cảnh',
          ),
          const SizedBox(height: 8),
          _ChartLegendItem(
            color: CineXPalette.accent,
            label: 'Ngoại cảnh (EXT)',
            value: '$exterior cảnh',
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: CineXPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: CineXPalette.textSecondary,
            fontWeight: FontWeight.w800,
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

class _DropdownText extends StatelessWidget {
  const _DropdownText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
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

Future<void> _showMemberSheet(
  BuildContext context, {
  ProjectMember? member,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _MemberSheet(member: member),
    ),
  );
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({this.member});

  final ProjectMember? member;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  late String _role;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _email.text = member?.email ?? '';
    _fullName.text = member?.fullName ?? '';
    _role = member?.role ?? 'VIEWER';
  }

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.member != null;
    final roles = editing && widget.member!.role == 'OWNER'
        ? const ['OWNER', ..._projectMemberRoles]
        : _projectMemberRoles;
    return _SheetFrame(
      title: editing ? 'Sửa thành viên' : 'Thêm thành viên',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              readOnly: editing,
              keyboardType: TextInputType.emailAddress,
              textInputAction:
                  editing ? TextInputAction.done : TextInputAction.next,
              validator: _emailValidator,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vai trò',
                prefixIcon: Icon(Icons.admin_panel_settings_rounded),
              ),
              items: roles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: _DropdownText(projectRoleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
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
              label: Text(editing ? 'Cập nhật' : 'Thêm thành viên'),
            ),
          ],
        ),
      ),
    );
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Email là bắt buộc';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : 'Email không hợp lệ';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<WorkspaceProvider>();
    final member = widget.member;
    final ok = member == null
        ? await provider.addMember(
            email: _email.text.trim(),
            fullName: _emptyToNull(_fullName.text),
            role: _role,
          )
        : await provider.updateMember(member, _role);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      context,
      ok ? 'Đã lưu thành viên' : provider.error ?? 'Không thể lưu thành viên',
    );
    if (ok) Navigator.pop(context, true);
  }
}

Future<void> _showActSheet(
  BuildContext context, {
  Act? act,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ActSheet(act: act),
    ),
  );
}

class _ActSheet extends StatefulWidget {
  const _ActSheet({this.act});

  final Act? act;

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
    final act = widget.act;
    _order = TextEditingController(
      text: act == null
          ? '${context.read<WorkspaceProvider>().acts.length + 1}'
          : '${act.sequenceOrder}',
    );
    if (act != null) {
      _title.text = act.title;
      _description.text = act.description ?? '';
    }
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
      title: widget.act == null ? 'Tạo hồi' : 'Sửa hồi',
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
    final provider = context.read<WorkspaceProvider>();
    final act = widget.act;
    final ok = act == null
        ? await provider.createAct(
            _title.text.trim(),
            int.parse(_order.text.trim()),
            description: _emptyToNull(_description.text),
          )
        : await provider.updateAct(
            act,
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
              isExpanded: true,
              validator: CharacterValidators.roleType,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: CharacterValidators.validRoleTypes
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: _DropdownText(characterRoleLabel(role)),
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
              isExpanded: true,
              validator: ResourceValidators.type,
              decoration: const InputDecoration(labelText: 'Loại'),
              items: ResourceValidators.validTypes
                  .map((type) => DropdownMenuItem(
                      value: type,
                      child: _DropdownText(resourceTypeLabel(type))))
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
              isExpanded: true,
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
                      child: _DropdownText(resourceStatusLabel(status)),
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

Future<void> _showSceneSheet(
  BuildContext context, {
  Scene? scene,
  int? initialActId,
}) async {
  final provider = context.read<WorkspaceProvider>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _SceneSheet(scene: scene, initialActId: initialActId),
    ),
  );
}

class _SceneSheet extends StatefulWidget {
  const _SceneSheet({this.scene, this.initialActId});

  final Scene? scene;
  final int? initialActId;

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
    final scene = widget.scene;
    _number = TextEditingController(
      text: scene == null ? '${provider.scenes.length + 1}' : '${scene.sceneNumber}',
    );
    _actId = scene?.actId ??
        widget.initialActId ??
        (provider.acts.isEmpty ? null : provider.acts.first.id);
    _storyLocationId = scene?.storyLocationId ??
        (provider.storyLocations.isEmpty ? null : provider.storyLocations.first.id);
    _shootingLocationId = scene?.plannedShootingLocationId;
    if (scene != null) {
      _title.text = scene.title ?? '';
      _summary.text = scene.summary;
      _minutes.text = '${scene.estimatedDurationMinutes}';
      _settingType = scene.settingType;
      _timeOfDay = scene.timeOfDay;
      _writingStatus = scene.writingStatus;
      _productionStatus = scene.productionStatus;
      _priority = scene.priority;
      _characters.addAll(scene.characters.map((character) => character.id));
      _resourceQuantities.addEntries(
        scene.resources.map(
          (resource) => MapEntry(resource.id, resource.requiredQuantity),
        ),
      );
    }
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
      title: widget.scene == null ? 'Tạo cảnh' : 'Sửa cảnh',
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
                validator: (_) {
                  final titleOrSummaryError =
                      SceneValidators.titleOrSummary(_title.text, _summary.text);
                  if (titleOrSummaryError != null) return titleOrSummaryError;
                  if (_writingStatus == 'DONE' &&
                      _summary.text.trim().isEmpty) {
                    return 'Cần nhập tóm tắt trước khi hoàn tất cảnh.';
                  }
                  return null;
                },
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Tóm tắt')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _actId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Hồi'),
              items: provider.acts
                  .map((act) => DropdownMenuItem<int>(
                        value: act.id,
                        child: _DropdownText(act.title),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _actId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _storyLocationId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bối cảnh truyện'),
              items: provider.storyLocations
                  .map((location) => DropdownMenuItem<int>(
                        value: location.id,
                        child: _DropdownText(location.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _storyLocationId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _shootingLocationId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Địa điểm quay thực tế'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: _DropdownText('Chưa gán'),
                ),
                ...provider.shootingLocations.map(
                  (location) => DropdownMenuItem<int?>(
                    value: location.id,
                    child: _DropdownText('${location.name}, ${location.address}'),
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
                    isExpanded: true,
                    validator: SceneValidators.settingType,
                    decoration: const InputDecoration(labelText: 'Bối cảnh'),
                    items: const ['INT', 'EXT']
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: _DropdownText(settingTypeLabel(value))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _settingType = value ?? _settingType),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _timeOfDay,
                    isExpanded: true,
                    validator: SceneValidators.timeOfDay,
                    decoration: const InputDecoration(labelText: 'Thời điểm'),
                    items: const ['DAY', 'NIGHT']
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: _DropdownText(timeOfDayLabel(value))))
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
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trạng thái viết'),
              items: SceneValidators.writingStatuses
                  .map((status) => DropdownMenuItem(
                      value: status,
                      child: _DropdownText(sceneStatusLabel(status))))
                  .toList(),
              onChanged: (value) {
                setState(() => _writingStatus = value ?? _writingStatus);
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _productionStatus,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Trạng thái sản xuất'),
              items: SceneValidators.productionStatuses
                  .map((status) => DropdownMenuItem(
                      value: status,
                      child: _DropdownText(productionStatusLabel(status))))
                  .toList(),
              onChanged: (value) => setState(
                  () => _productionStatus = value ?? _productionStatus),
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
    final provider = context.read<WorkspaceProvider>();
    final scene = widget.scene;
    final resourceRequirements = _resourceQuantities.entries
        .map((entry) =>
            {'resourceId': entry.key, 'requiredQuantity': entry.value})
        .toList();
    final ok = scene == null
        ? await provider.createScene(
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
            resourceRequirements: resourceRequirements,
          )
        : await provider.updateScene(
            scene.id,
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
            resourceRequirements: resourceRequirements,
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
  final Set<int> _sceneIdsToAdd = {};
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
    final provider = context.watch<WorkspaceProvider>();
    final additionalScenes = provider.unscheduledScenes
        .where((scene) => _sceneIdsToAdd.contains(scene.id))
        .toList();
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
              additionalScenes: additionalScenes,
            ),
            const SizedBox(height: 12),
            _ShootingDayScenePicker(
              existingDay: widget.day,
              scenes: provider.unscheduledScenes,
              selectedSceneIds: _sceneIdsToAdd,
              enabled: !_saving,
              onChanged: (scene, selected) {
                setState(() {
                  if (selected) {
                    _sceneIdsToAdd.add(scene.id);
                  } else {
                    _sceneIdsToAdd.remove(scene.id);
                  }
                });
              },
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
    final provider = context.read<WorkspaceProvider>();
    final day = widget.day;
    final additionalMinutes = provider.unscheduledScenes
        .where((scene) => _sceneIdsToAdd.contains(scene.id))
        .fold<int>(0, (sum, scene) => sum + scene.estimatedDurationMinutes);
    final maxMinutes = int.parse(_max.text.trim());
    final projectedMinutes = (day?.totalMinutes ?? 0) + additionalMinutes;
    if (projectedMinutes > maxMinutes) {
      _snack(context, 'Tổng thời lượng cảnh vượt quá số phút tối đa.');
      return;
    }
    setState(() => _saving = true);
    final ok = day == null
        ? await provider.createShootingDay(
            date: _date!,
            title: _title.text.trim(),
            maxMinutes: maxMinutes,
            notes: _emptyToNull(_notes.text),
            sceneIdsToAdd: _sceneIdsToAdd.toList(),
          )
        : await provider.updateShootingDay(
            day.id,
            date: _date!,
            title: _title.text.trim(),
            maxMinutes: maxMinutes,
            notes: _emptyToNull(_notes.text),
            sceneIdsToAdd: _sceneIdsToAdd.toList(),
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

class _ShootingDayScenePicker extends StatelessWidget {
  const _ShootingDayScenePicker({
    required this.existingDay,
    required this.scenes,
    required this.selectedSceneIds,
    required this.enabled,
    required this.onChanged,
  });

  final ShootingDay? existingDay;
  final List<Scene> scenes;
  final Set<int> selectedSceneIds;
  final bool enabled;
  final void Function(Scene scene, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(110),
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
                  Icons.movie_filter_rounded,
                  color: CineXPalette.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cảnh quay',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: CineXPalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if ((existingDay?.scenes ?? const <ShootingDayScene>[]).isNotEmpty)
              ...existingDay!.scenes.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_circle_rounded),
                  title: Text(item.scene.sceneHeading),
                  subtitle: Text(
                    '${item.plannedStartTime ?? '--:--'} - '
                    '${item.plannedEndTime ?? '--:--'}',
                  ),
                ),
              ),
            if (scenes.isEmpty)
              const _MutedText('Không có cảnh sẵn sàng để thêm.')
            else
              ...scenes.map(
                (scene) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selectedSceneIds.contains(scene.id),
                  onChanged: enabled
                      ? (selected) => onChanged(scene, selected == true)
                      : null,
                  title: Text(scene.sceneHeading),
                  subtitle: Text(
                    '${scene.shootingLocationLabel} · '
                    '${scene.estimatedDurationMinutes} phút',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShootingDayFormDetail extends StatelessWidget {
  const _ShootingDayFormDetail({
    required this.day,
    required this.date,
    required this.title,
    required this.maxMinutesText,
    required this.notes,
    required this.additionalScenes,
  });

  final ShootingDay? day;
  final DateTime? date;
  final String title;
  final String maxMinutesText;
  final String notes;
  final List<Scene> additionalScenes;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final effectiveTitle = title.trim().isEmpty ? 'Ngày quay' : title.trim();
    final maxMinutes =
        int.tryParse(maxMinutesText.trim()) ?? day?.maxMinutes ?? 0;
    final additionalMinutes = additionalScenes.fold<int>(
      0,
      (sum, scene) => sum + scene.estimatedDurationMinutes,
    );
    final totalMinutes = (day?.totalMinutes ?? 0) + additionalMinutes;
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
            if (scenes.isEmpty && additionalScenes.isEmpty)
              const _MutedText('Chưa có cảnh trong ngày quay này.')
            else ...[
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
              ...additionalScenes.map(
                (scene) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: CineXPalette.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scene.sceneHeading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${scene.estimatedDurationMinutes} phút',
                        style: const TextStyle(
                          color: CineXPalette.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

ImageProvider<Object>? _avatarImage(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  return FileImage(File(source));
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return '$first$second'.toUpperCase();
}

String _percentLabel(int value, int total) {
  if (total == 0) return '0%';
  return '${(value * 100 / total).round()}%';
}

String? _emptyToNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
