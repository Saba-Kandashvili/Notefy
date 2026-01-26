import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/tuning_model.dart';
import '../domain/tuning_mode.dart';

/// Repository for persisting tuner state
class TunerRepository {
  static const _keyTuningMode = 'tuning_mode';
  static const _keyGuitarPreset = 'guitar_preset';
  static const _keyCustomPresets = 'custom_presets_list';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save the current tuning mode
  Future<void> saveTuningMode(TuningMode mode) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyTuningMode, mode.index);
  }

  /// Load the saved tuning mode
  Future<TuningMode> loadTuningMode() async {
    final prefs = await _preferences;
    final index = prefs.getInt(_keyTuningMode);
    if (index != null && index < TuningMode.values.length) {
      return TuningMode.values[index];
    }
    return TuningMode.chromatic;
  }

  /// Save the current guitar preset
  Future<void> saveGuitarPreset(TuningPreset preset) async {
    final prefs = await _preferences;
    await prefs.setString(_keyGuitarPreset, jsonEncode(preset.toJson()));
  }

  /// Load the saved guitar preset
  Future<TuningPreset?> loadGuitarPreset() async {
    final prefs = await _preferences;
    final json = prefs.getString(_keyGuitarPreset);
    if (json != null) {
      try {
        return TuningPreset.fromJson(jsonDecode(json));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Save custom presets list
  Future<void> saveCustomPresets(List<TuningPreset> presets) async {
    final prefs = await _preferences;
    final jsonList = presets.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_keyCustomPresets, jsonList);
  }

  /// Load custom presets list
  Future<List<TuningPreset>> loadCustomPresets() async {
    final prefs = await _preferences;
    final jsonList = prefs.getStringList(_keyCustomPresets);
    if (jsonList != null) {
      try {
        return jsonList
            .map((str) => TuningPreset.fromJson(jsonDecode(str)))
            .toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }
}
