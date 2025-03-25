import 'package:flutter/material.dart';
import '../models/blind_settings.dart';
import '../services/settings_service.dart';
import '../widgets/chip_level_editor.dart';

class SettingsPage extends StatefulWidget {
  final SettingsService settingsService;
  final Function(BlindSettings) onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late BlindSettings _settings;
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = [];
  bool _hasUnsavedChanges = false;
  late List<ChipLevel> _chipLevels;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsService.getSettings();
    _chipLevels = List.from(_settings.chipLevels);
    _volume = _settings.volume;
    _initializeControllers();
  }

  void _initializeControllers() {
    _controllers.clear();
    for (final interval in _settings.intervals) {
      final controller = TextEditingController(text: interval.toString());
      controller.addListener(_onControllerChanged);
      _controllers.add(controller);
    }
  }

  void _onControllerChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _saveSettings() async {
    if (!_hasUnsavedChanges) return true;
    if (_formKey.currentState?.validate() ?? false) {
      final newIntervals = _controllers
          .map((controller) => int.parse(controller.text))
          .toList();
      
      final newSettings = _settings.copyWith(
        intervals: newIntervals,
        chipLevels: _chipLevels,
      );
      await widget.settingsService.saveSettings(newSettings);
      widget.onSettingsChanged(newSettings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
      setState(() {
        _hasUnsavedChanges = false;
      });
      return true;
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return false;
    if (!result) return true;
    return _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Blind Intervals (minutes)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._buildIntervalFields(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final controller = TextEditingController(text: '15');
                      controller.addListener(_onControllerChanged);
                      setState(() {
                        _controllers.add(controller);
                        _hasUnsavedChanges = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Interval'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sound Volume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_off),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(_volume * 100).round()}%',
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const Text(
              'Chip Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ChipLevelEditor(
              chipLevels: _chipLevels,
              onChipLevelsChanged: (levels) {
                setState(() {
                  _chipLevels = levels;
                  _hasUnsavedChanges = true;
                });
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (await _saveSettings()) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save and Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  List<Widget> _buildIntervalFields() {
    return List.generate(_controllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controllers[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Interval ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            if (_controllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  setState(() {
                    _controllers[index].dispose();
                    _controllers.removeAt(index);
                    _hasUnsavedChanges = true;
                  });
                },
              ),
          ],
        ),
      );
    });
  }
}
