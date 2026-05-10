import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class EditActivityDialog extends StatefulWidget {
  final UserActivityEntity activityEntity;

  const EditActivityDialog({super.key, required this.activityEntity});

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.activityEntity.duration.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).editItemDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: S.of(context).quantityLabel,
              suffixText: 'min',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            final parsed = double.tryParse(_durationController.text);
            if (parsed != null && parsed > 0) {
              Navigator.of(context).pop(parsed);
            }
          },
          child: Text(S.of(context).dialogOKLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.of(context).dialogCancelLabel),
        ),
      ],
    );
  }
}
