import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/tuning_model.dart';
import '../../../core/theme/app_theme.dart';

class TuningEditor extends StatefulWidget {
  final TuningPreset initialPreset;
  const TuningEditor({super.key, required this.initialPreset});

  @override
  State<TuningEditor> createState() => _TuningEditorState();
}

class _TuningEditorState extends State<TuningEditor> {
  late TuningPreset _editingPreset;
  late TextEditingController _nameController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _editingPreset = widget.initialPreset.copy();
    _nameController = TextEditingController(text: _editingPreset.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _addString() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_editingPreset.strings.isEmpty) {
        _editingPreset.strings.add(InstrumentString(note: "E", octave: 2));
      } else {
        var lowest = _editingPreset.strings.first;
        _editingPreset.strings.insert(
          0,
          NoteUtils.calculateNextLowerString(
            lowest,
            existingStrings: _editingPreset.strings,
          ),
        );
      }
      _hasChanges = true;
    });
  }

  void _removeString(int index) {
    if (_editingPreset.strings.length <= 1) return;
    HapticFeedback.lightImpact();
    setState(() {
      _editingPreset.strings.removeAt(index);
      _hasChanges = true;
    });
  }

  void _showNotePicker(int index) {
    final str = _editingPreset.strings[index];
    String selectedNote = str.note;
    int selectedOctave = str.octave;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Edit String ${index + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Note selector
              const Text(
                "Note",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: NOTE_NAMES.map((note) {
                  final isSelected = selectedNote == note;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => selectedNote = note);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryAccent
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryAccent
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          note,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Octave selector
              const Text(
                "Octave",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(9, (i) {
                    final isSelected = selectedOctave == i;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => selectedOctave = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.inTuneColor
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "$i",
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Preview
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "$selectedNote$selectedOctave",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${NoteUtils.getFrequency(selectedNote, selectedOctave).toStringAsFixed(2)} Hz",
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      str.note = selectedNote;
                      str.octave = selectedOctave;
                      _hasChanges = true;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text(
          "Discard Changes?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "You have unsaved changes. Do you want to discard them?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Discard",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text("Edit Tuning"),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.check, color: Colors.greenAccent),
              label: const Text(
                "Save",
                style: TextStyle(color: Colors.greenAccent),
              ),
              onPressed: () {
                _editingPreset.name = _nameController.text.trim().isEmpty
                    ? "Custom Tuning"
                    : _nameController.text.trim();
                Navigator.pop(context, _editingPreset);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Preset name input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Preset Name",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.music_note,
                    color: Colors.white54,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (_) => _markChanged(),
              ),
            ),

            // String count indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "${_editingPreset.strings.length} Strings",
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Drag to reorder • Swipe to delete",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // String list with reorder support
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _editingPreset.strings.length,
                onReorder: (oldIndex, newIndex) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _editingPreset.strings.removeAt(oldIndex);
                    _editingPreset.strings.insert(newIndex, item);
                    _hasChanges = true;
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final elevation = Tween<double>(
                        begin: 0,
                        end: 8,
                      ).animate(animation).value;
                      return Material(
                        elevation: elevation,
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final str = _editingPreset.strings[index];
                  final canDelete = _editingPreset.strings.length > 1;

                  return Dismissible(
                    key: ValueKey('string_$index'),
                    direction: canDelete
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    onDismissed: (_) => _removeString(index),
                    child: _StringCard(
                      key: ValueKey('card_$index'),
                      index: index,
                      string: str,
                      totalStrings: _editingPreset.strings.length,
                      onTap: () => _showNotePicker(index),
                    ),
                  );
                },
              ),
            ),

            // Add string button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addString,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Lower String"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryAccent,
                      side: BorderSide(
                        color: AppColors.primaryAccent.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StringCard extends StatelessWidget {
  final int index;
  final InstrumentString string;
  final int totalStrings;
  final VoidCallback onTap;

  const _StringCard({
    super.key,
    required this.index,
    required this.string,
    required this.totalStrings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // String thickness visualization (thicker for bass strings)
    final thickness = 4.0 + (totalStrings - 1 - index) * 0.8;
    final progress = totalStrings > 1 ? index / (totalStrings - 1) : 0.5;

    // Color: bass = bronze, treble = silver
    final stringColor = progress < 0.5
        ? Color.lerp(
            const Color(0xFFCD853F),
            const Color(0xFFB8860B),
            progress * 2,
          )!
        : Color.lerp(
            const Color(0xFFB8860B),
            const Color(0xFFC0C0C0),
            (progress - 0.5) * 2,
          )!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // String number with visual thickness
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: stringColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // String line visualization
                  Container(
                    width: thickness,
                    height: 30,
                    decoration: BoxDecoration(
                      color: stringColor,
                      borderRadius: BorderRadius.circular(thickness / 2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Note info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${string.note}${string.octave}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    "${string.frequency.toStringAsFixed(2)} Hz",
                    style: TextStyle(
                      color: AppColors.primaryAccent.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // String number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "String ${index + 1}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
