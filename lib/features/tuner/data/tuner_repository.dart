import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      debugPrint('TunerRepository: Failed to get SharedPreferences: $e');
      rethrow;
    }
  }

  /// Save the current tuning mode
  Future<bool> saveTuningMode(TuningMode mode) async {
    try {
      final prefs = await _preferences;
      return await prefs.setInt(_keyTuningMode, mode.index);
    } catch (e) {
      debugPrint('TunerRepository: Failed to save tuning mode: $e');
      return false;
    }
  }

  /// Load the saved tuning mode
  Future<TuningMode> loadTuningMode() async {
    try {
      final prefs = await _preferences;
      final index = prefs.getInt(_keyTuningMode);
      if (index != null && index >= 0 && index < TuningMode.values.length) {
        return TuningMode.values[index];
      }
    } catch (e) {
      debugPrint('TunerRepository: Failed to load tuning mode: $e');
    }
    return TuningMode.chromatic;
  }

  /// Save the current guitar preset
  Future<bool> saveGuitarPreset(TuningPreset preset) async {
    try {
      final prefs = await _preferences;
      return await prefs.setString(
        _keyGuitarPreset,
        jsonEncode(preset.toJson()),
      );
    } catch (e) {
      debugPrint('TunerRepository: Failed to save guitar preset: $e');
      return false;
    }
  }

  /// Load the saved guitar preset
  Future<TuningPreset?> loadGuitarPreset() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_keyGuitarPreset);
      if (json != null && json.isNotEmpty) {
        return TuningPreset.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('TunerRepository: Failed to load guitar preset: $e');
    }
    return null;
  }

  /// Save custom presets list
  Future<bool> saveCustomPresets(List<TuningPreset> presets) async {
    try {
      final prefs = await _preferences;
      final jsonList = presets.map((p) => jsonEncode(p.toJson())).toList();
      return await prefs.setStringList(_keyCustomPresets, jsonList);
    } catch (e) {
      debugPrint('TunerRepository: Failed to save custom presets: $e');
      return false;
    }
  }

  /// Load custom presets list
  Future<List<TuningPreset>> loadCustomPresets() async {
    try {
      final prefs = await _preferences;
      final jsonList = prefs.getStringList(_keyCustomPresets);
      if (jsonList != null && jsonList.isNotEmpty) {
        return jsonList
            .map((str) => TuningPreset.fromJson(jsonDecode(str)))
            .toList();
      }
    } catch (e) {
      debugPrint('TunerRepository: Failed to load custom presets: $e');
    }
    return [];
  }

  /// Clear all saved data (for debugging/reset)
  Future<bool> clearAll() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_keyTuningMode);
      await prefs.remove(_keyGuitarPreset);
      await prefs.remove(_keyCustomPresets);
      return true;
    } catch (e) {
      debugPrint('TunerRepository: Failed to clear data: $e');
      return false;
    }
  }
}
