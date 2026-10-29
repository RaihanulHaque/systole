import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReferenceInput {
  final double sbp;
  final double dbp;
  final bool calibrate;
  const ReferenceInput(this.sbp, this.dbp, this.calibrate);
}

/// Asks for a cuff reading. Returns null if cancelled.
Future<ReferenceInput?> showReferenceDialog(
  BuildContext context, {
  bool calibrateByDefault = true,
}) {
  return showModalBottomSheet<ReferenceInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReferenceSheet(calibrateByDefault: calibrateByDefault),
  );
}

class _ReferenceSheet extends StatefulWidget {
  const _ReferenceSheet({required this.calibrateByDefault});

  final bool calibrateByDefault;

  @override
  State<_ReferenceSheet> createState() => _ReferenceSheetState();
}

class _ReferenceSheetState extends State<_ReferenceSheet> {
  final _form = GlobalKey<FormState>();
  final _sbp = TextEditingController();
  final _dbp = TextEditingController();
  late bool _calibrate = widget.calibrateByDefault;

  @override
  void dispose() {
    _sbp.dispose();
    _dbp.dispose();
    super.dispose();
  }

  String? _validate(String? v, double lo, double hi) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Required';
    if (n < lo || n > hi) return '${lo.toInt()}–${hi.toInt()}';
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final sbp = double.parse(_sbp.text);
    final dbp = double.parse(_dbp.text);
    if (sbp <= dbp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Systolic must be higher than diastolic')),
      );
      return;
    }
    Navigator.pop(context, ReferenceInput(sbp, dbp, _calibrate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuff reading', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Measure with a validated cuff monitor on the same arm while '
              'seated and still, then enter the result.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sbp,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: 'Systolic',
                      suffixText: 'mmHg',
                    ),
                    validator: (v) => _validate(v, 60, 260),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dbp,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: 'Diastolic',
                      suffixText: 'mmHg',
                    ),
                    validator: (v) => _validate(v, 30, 160),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _calibrate,
              onChanged: (v) => setState(() => _calibrate = v),
              title: const Text('Calibrate the sensor with this reading'),
              subtitle: const Text(
                'Off: saved only as a reference to check accuracy',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(_calibrate ? 'Calibrate' : 'Save reference'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
