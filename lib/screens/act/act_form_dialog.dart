import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/act.dart';
import '../../providers/act_provider.dart';

class ActFormDialog extends StatefulWidget {
  const ActFormDialog({super.key, required this.projectId, this.act});

  final int projectId;
  final Act? act;

  @override
  State<ActFormDialog> createState() => _ActFormDialogState();
}

class _ActFormDialogState extends State<ActFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _sequenceController;
  bool _isSaving = false;
  bool _isLoadingSequence = false;

  bool get _isEditing => widget.act != null;

  @override
  void initState() {
    super.initState();
    final act = widget.act;
    _titleController = TextEditingController(text: act?.title ?? '');
    _sequenceController = TextEditingController(
      text: act?.sequenceOrder.toString() ?? '',
    );

    if (act == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNextSequenceOrder();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Act' : 'New Act'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.view_timeline_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Act title is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sequenceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sequence order',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  suffixIcon: _isLoadingSequence
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null) {
                    return 'Enter a positive number.';
                  }

                  if (parsed <= 0) {
                    return 'Sequence order must be positive.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveAct,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _loadNextSequenceOrder() async {
    setState(() {
      _isLoadingSequence = true;
    });

    final provider = context.read<ActProvider>();
    final nextOrder = await provider.getNextSequenceOrder(widget.projectId);

    if (!mounted) {
      return;
    }

    setState(() {
      _sequenceController.text = nextOrder.toString();
      _isLoadingSequence = false;
    });
  }

  Future<void> _saveAct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<ActProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existingAct = widget.act;

    setState(() {
      _isSaving = true;
    });

    final act = Act(
      id: existingAct?.id,
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      sequenceOrder: int.parse(_sequenceController.text.trim()),
    );

    final success = _isEditing
        ? await provider.updateAct(act)
        : await provider.addAct(act);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _isEditing
                    ? 'Act updated.'
                    : 'Act created.'
              : provider.errorMessage ?? 'Could not save act.',
        ),
      ),
    );

    if (success) {
      navigator.pop(true);
    }
  }
}
