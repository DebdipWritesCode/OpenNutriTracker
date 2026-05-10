import 'package:flutter/material.dart';
import 'package:horizontal_picker/horizontal_picker.dart';
import 'package:opennutritracker/features/profile/presentation/utils/profile_picker_bounds.dart';
import 'package:opennutritracker/generated/l10n.dart';

class SetWeightDialog extends StatefulWidget {
  final double userWeight;
  final bool usesImperialUnits;

  const SetWeightDialog({
    super.key,
    required this.userWeight,
    required this.usesImperialUnits,
  });

  @override
  State<SetWeightDialog> createState() => _SetWeightDialogState();
}

class _SetWeightDialogState extends State<SetWeightDialog> {
  late double selectedWeight;

  @override
  void initState() {
    super.initState();
    selectedWeight = widget.userWeight;
  }

  @override
  Widget build(BuildContext context) {
    final minWeight =
        minSelectableWeight(widget.userWeight, widget.usesImperialUnits);
    final maxWeight =
        maxSelectableWeight(widget.userWeight, widget.usesImperialUnits);

    return AlertDialog(
      title: Text(S.of(context).selectWeightDialogLabel),
      content: Wrap(
        children: [
          Column(
            children: [
              HorizontalPicker(
                height: 100,
                backgroundColor: Colors.transparent,
                minValue: minWeight,
                maxValue: maxWeight,
                initialPosition: InitialPosition.center,
                divisions: 1000, // Supports decimal values (#244)
                suffix: widget.usesImperialUnits
                    ? S.of(context).lbsLabel
                    : S.of(context).kgLabel,
                onChanged: (value) {
                  setState(() {
                    selectedWeight = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(S.of(context).dialogCancelLabel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              clampWeightSelection(selectedWeight, minWeight),
            );
          },
          child: Text(S.of(context).dialogOKLabel),
        ),
      ],
    );
  }
}
