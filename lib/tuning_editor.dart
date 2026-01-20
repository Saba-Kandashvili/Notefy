import 'package:flutter/material.dart';

import '../tuning_model.dart';

class TuningEditor extends StatefulWidget {
  final TuningPreset initialPreset;
  const TuningEditor({super.key, required this.initialPreset});

  @override
  _TuningEditorState createState() => _TuningEditorState();
}

class _TuningEditorState extends State<TuningEditor> {
  late TuningPreset _editingPreset;

  @override
  void initState() {
    super.initState();
    // Create a deep copy so we do not mutate the main app state until save
    _editingPreset = widget.initialPreset.copy();
  }

  void _addString() {
    setState(() {
      var lowest = _editingPreset.strings.first;
      // Use NoteUtils.calculateNextLowerString to insert the next lower string
      _editingPreset.strings.insert(
        0,
        NoteUtils.calculateNextLowerString(lowest),
      );
    });
  }

  void _removeString(int index) {
    if (_editingPreset.strings.length <= 1) return;
    setState(() {
      _editingPreset.strings.removeAt(index);
    });
  }

  // --- NOTE PICKER DIALOG ---
  void _editStringNote(int index) {
    InstrumentString str = _editingPreset.strings[index];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Select Note"),
        children: [
          SizedBox(
            height: 200,
            width: double.maxFinite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Note Name Wheel
                SizedBox(
                  width: 60,
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) => str.note = NOTE_NAMES[i],
                    childDelegate: ListWheelChildLoopingListDelegate(
                      children: NOTE_NAMES
                          .map(
                            (n) => Center(
                              child: Text(
                                n,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Octave Wheel
                SizedBox(
                  width: 60,
                  child: ListWheelScrollView(
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    children: List.generate(
                      9,
                      (i) => Center(
                        child: Text("$i", style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    onSelectedItemChanged: (i) => str.octave = i,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {}); // Refresh list
              Navigator.pop(ctx);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Edit Tuning"),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: () {
              // Return the modified preset
              Navigator.pop(context, _editingPreset);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Name & Style
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: TextEditingController(text: _editingPreset.name),
                  decoration: const InputDecoration(labelText: "Preset Name"),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => _editingPreset.name = val,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Headstock Style:",
                      style: TextStyle(color: Colors.white70),
                    ),
                    DropdownButton<HeadstockStyle>(
                      value: _editingPreset.style,
                      dropdownColor: const Color(0xFF2D2D44),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: HeadstockStyle.twoWay,
                          child: Text("2-Way (Gibson)"),
                        ),
                        DropdownMenuItem(
                          value: HeadstockStyle.oneWay,
                          child: Text("1-Way (Ibanez)"),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _editingPreset.style = val!),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // 2. String Manager
          Expanded(
            child: ListView.builder(
              itemCount:
                  _editingPreset.strings.length +
                  1, // +1 for "Add String" button
              itemBuilder: (context, index) {
                if (index == _editingPreset.strings.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Low String"),
                        onPressed: _addString,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  );
                }

                var str = _editingPreset.strings[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.greenAccent.withOpacity(0.2),
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                  title: Text(
                    "${str.note}${str.octave}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  subtitle: Text(
                    "${str.frequency.toStringAsFixed(2)} Hz",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _editStringNote(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _removeString(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
