import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../state/monitor_controller.dart';
import '../../state/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _age, _height, _weight;
  late bool _isMale;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileController>().profile;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age.toString());
    _height = TextEditingController(text: _trim(p.heightCm));
    _weight = TextEditingController(text: _trim(p.weightKg));
    _isMale = p.isMale;
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _range(String? v, double lo, double hi) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Required';
    if (n < lo || n > hi) return '${lo.toInt()}–${hi.toInt()}';
    return null;
  }

  double? get _bmi {
    final h = double.tryParse(_height.text), w = double.tryParse(_weight.text);
    if (h == null || w == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = UserProfile(
      name: _name.text.trim(),
      age: int.parse(_age.text),
      isMale: _isMale,
      heightCm: double.parse(_height.text),
      weightKg: double.parse(_weight.text),
    );
    await context.read<ProfileController>().update(p);
    if (!mounted) return;
    final monitor = context.read<MonitorController>();
    if (monitor.connected) await monitor.syncProfile();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          monitor.connected
              ? 'Profile saved and sent to sensor'
              : 'Profile saved. It is sent when the sensor connects.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monitor = context.watch<MonitorController>();
    final info = monitor.device?.info;
    final num = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final bmi = _bmi;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'The blood pressure model uses these values as inputs. Keep them up to date.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      suffixText: 'years',
                    ),
                    validator: (v) => _range(v, 10, 110),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Male')),
                      ButtonSegment(value: false, label: Text('Female')),
                    ],
                    selected: {_isMale},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _isMale = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: num,
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                    validator: (v) => _range(v, 100, 230),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: num,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                    ),
                    validator: (v) => _range(v, 25, 250),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              bmi == null || bmi.isNaN || bmi.isInfinite
                  ? 'BMI --'
                  : 'BMI ${bmi.toStringAsFixed(1)}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 32),
            Text('Sensor', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: monitor.device == null
                  ? const ListTile(
                      leading: Icon(Icons.sensors_off),
                      title: Text('Not connected'),
                    )
                  : Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.sensors),
                          title: Text(monitor.device!.name),
                          subtitle: Text(monitor.device!.id),
                        ),
                        if (info != null) ...[
                          _InfoRow('Firmware', info.firmware),
                          _InfoRow('Model version', 'v${info.modelVersion}'),
                          _InfoRow('Sample rate', '${info.sampleRateHz} Hz'),
                        ],
                        _InfoRow(
                          'Calibration',
                          monitor.calibrated ? 'Calibrated' : 'Not calibrated',
                        ),
                        if (monitor.battery != null)
                          _InfoRow('Battery', '${monitor.battery}%'),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            Text('About', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Systole is a research prototype for continuous, cuffless blood '
                  'pressure estimation. A wrist PPG sensor runs the model on the '
                  'device and streams results to this app over Bluetooth Low Energy.\n\n'
                  'Estimates can be wrong. Do not use them for diagnosis or treatment. '
                  'Confirm readings with a validated cuff and ask a clinician about any concerns.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
