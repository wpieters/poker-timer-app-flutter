import 'package:flutter/material.dart';
import '../models/blind_settings.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ChipLevelEditor extends StatefulWidget {
  final List<ChipLevel> chipLevels;
  final Function(List<ChipLevel>) onChipLevelsChanged;

  const ChipLevelEditor({
    super.key,
    required this.chipLevels,
    required this.onChipLevelsChanged,
  });

  @override
  State<ChipLevelEditor> createState() => _ChipLevelEditorState();
}

class _ChipLevelEditorState extends State<ChipLevelEditor> {
  late List<ChipLevel> _chipLevels;

  @override
  void initState() {
    super.initState();
    _chipLevels = List.from(widget.chipLevels);
  }

  void _showColorPicker(int index, bool isSmallBlind) {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = isSmallBlind
            ? _chipLevels[index].smallBlindColor
            : _chipLevels[index].bigBlindColor;

        return AlertDialog(
          title: Text('Pick ${isSmallBlind ? 'Small' : 'Big'} Blind Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final updatedLevel = _chipLevels[index].copyWith(
                    smallBlindColor: isSmallBlind ? pickerColor : null,
                    bigBlindColor: isSmallBlind ? null : pickerColor,
                  );
                  _chipLevels[index] = updatedLevel;
                });
                widget.onChipLevelsChanged(_chipLevels);
                Navigator.pop(context);
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  void _updateMultiplier(int index, int value) {
    setState(() {
      final updatedLevel = _chipLevels[index].copyWith(
        bigBlindMultiplier: value,
      );
      _chipLevels[index] = updatedLevel;
    });
    widget.onChipLevelsChanged(_chipLevels);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Chip Colors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _chipLevels.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              // Create a new list and manipulate it to avoid removeAt which can cause issues in web
              final List<ChipLevel> newList = List.from(_chipLevels);
              final item = newList[oldIndex];
              newList.removeAt(oldIndex);
              newList.insert(newIndex, item);
              _chipLevels = newList;
            });
            widget.onChipLevelsChanged(_chipLevels);
          },
          itemBuilder: (context, index) {
            final level = _chipLevels[index];
            return Card(
              key: ValueKey(index),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.drag_handle),
                      onPressed: null,
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showColorPicker(index, true),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: level.smallBlindColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showColorPicker(index, false),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: level.bigBlindColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<int>(
                            value: level.bigBlindMultiplier,
                            items: [1, 2, 4, 8, 16, 32, 64, 128]
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('×$value'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateMultiplier(index, value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_chipLevels.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            // Create a new list without the item at index to avoid removeAt
                            final indexToRemove = index; // Store the index to remove
                            _chipLevels = List.from(_chipLevels.asMap().entries
                              .where((entry) => entry.key != indexToRemove)
                              .map((entry) => entry.value)
                              .toList());
                          });
                          widget.onChipLevelsChanged(_chipLevels);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _chipLevels.add(
                const ChipLevel(
                  smallBlindColor: Colors.blue,
                  bigBlindColor: Colors.white,
                  bigBlindMultiplier: 1,
                ),
              );
            });
            widget.onChipLevelsChanged(_chipLevels);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Chip Level'),
        ),
      ],
    );
  }
}
