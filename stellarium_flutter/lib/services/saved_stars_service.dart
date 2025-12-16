import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved star entry
class SavedStar {
  final String id; // Unique identifier (e.g., "HIP14778" or registration number)
  final String displayName; // Name to show in the list
  final String? scientificName; // Scientific identifier
  final String? registrationNumber; // Registration number if from registry
  final double? ra; // Right ascension in degrees
  final double? dec; // Declination in degrees
  final double? magnitude;
  final DateTime savedAt;
  final bool notificationsEnabled; // Whether visibility notifications are enabled

  SavedStar({
    required this.id,
    required this.displayName,
    this.scientificName,
    this.registrationNumber,
    this.ra,
    this.dec,
    this.magnitude,
    DateTime? savedAt,
    this.notificationsEnabled = true, // Default: notifications enabled
  }) : savedAt = savedAt ?? DateTime.now();

  /// Create a search query to find this star
  String get searchQuery {
    // If we have a scientific name, format it with space
    if (scientificName != null && scientificName!.isNotEmpty) {
      final match = RegExp(r'^([A-Za-z]+)(\d.*)$').firstMatch(scientificName!);
      if (match != null) {
        return '${match.group(1)} ${match.group(2)}';
      }
      return scientificName!;
    }
    return displayName;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'scientificName': scientificName,
      'registrationNumber': registrationNumber,
      'ra': ra,
      'dec': dec,
      'magnitude': magnitude,
      'savedAt': savedAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory SavedStar.fromJson(Map<String, dynamic> json) {
    return SavedStar(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      scientificName: json['scientificName'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      ra: (json['ra'] as num?)?.toDouble(),
      dec: (json['dec'] as num?)?.toDouble(),
      magnitude: (json['magnitude'] as num?)?.toDouble(),
      savedAt: json['savedAt'] != null
          ? DateTime.parse(json['savedAt'] as String)
          : DateTime.now(),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  /// Create a copy with updated fields
  SavedStar copyWith({
    String? id,
    String? displayName,
    String? scientificName,
    String? registrationNumber,
    double? ra,
    double? dec,
    double? magnitude,
    DateTime? savedAt,
    bool? notificationsEnabled,
  }) {
    return SavedStar(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      scientificName: scientificName ?? this.scientificName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      ra: ra ?? this.ra,
      dec: dec ?? this.dec,
      magnitude: magnitude ?? this.magnitude,
      savedAt: savedAt ?? this.savedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

/// Service for managing saved stars
class SavedStarsService extends ChangeNotifier {
  static const String _storageKey = 'saved_stars';
  static SavedStarsService? _instance;

  final List<SavedStar> _savedStars = [];
  bool _isLoaded = false;

  SavedStarsService._();

  /// Get the singleton instance
  static SavedStarsService get instance {
    _instance ??= SavedStarsService._();
    return _instance!;
  }

  /// Get all saved stars
  List<SavedStar> get savedStars => List.unmodifiable(_savedStars);

  /// Check if loaded
  bool get isLoaded => _isLoaded;

  /// Load saved stars from storage
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _savedStars.clear();
        _savedStars.addAll(
          jsonList.map((json) => SavedStar.fromJson(json as Map<String, dynamic>)),
        );
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved stars: $e');
      _isLoaded = true;
    }
  }

  /// Save to storage
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _savedStars.map((star) => star.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving stars: $e');
    }
  }

  /// Check if a star is saved by its ID
  bool isSaved(String id) {
    return _savedStars.any((star) => star.id == id);
  }

  /// Find a saved star by its scientific name (e.g., "HIP14778" or "HIP 14778")
  SavedStar? findByScientificName(String scientificName) {
    // Normalize the name by removing spaces for comparison
    final normalized = scientificName.replaceAll(' ', '').toUpperCase();
    return _savedStars.cast<SavedStar?>().firstWhere(
      (star) {
        if (star?.scientificName == null) return false;
        final starNormalized = star!.scientificName!.replaceAll(' ', '').toUpperCase();
        return starNormalized == normalized;
      },
      orElse: () => null,
    );
  }

  /// Find a saved star by ID
  SavedStar? findById(String id) {
    return _savedStars.cast<SavedStar?>().firstWhere(
      (star) => star?.id == id,
      orElse: () => null,
    );
  }

  /// Save a star
  Future<void> saveStar(SavedStar star) async {
    // Don't add duplicates - check by ID
    if (isSaved(star.id)) return;

    // Also check by scientific name to catch edge cases
    if (star.scientificName != null && star.scientificName!.isNotEmpty) {
      if (findByScientificName(star.scientificName!) != null) return;
    }

    _savedStars.insert(0, star); // Add to beginning
    notifyListeners();
    await _save();
  }

  /// Remove a star by ID
  Future<void> removeStar(String id) async {
    _savedStars.removeWhere((star) => star.id == id);
    notifyListeners();
    await _save();
  }

  /// Toggle save state for a star
  Future<bool> toggleStar(SavedStar star) async {
    // Check if already saved by ID or scientific name
    final existingById = findById(star.id);
    final existingByName = star.scientificName != null && star.scientificName!.isNotEmpty
        ? findByScientificName(star.scientificName!)
        : null;
    final existing = existingById ?? existingByName;

    if (existing != null) {
      await removeStar(existing.id);
      return false;
    } else {
      await saveStar(star);
      return true;
    }
  }

  /// Clear all saved stars
  Future<void> clearAll() async {
    _savedStars.clear();
    notifyListeners();
    await _save();
  }

  /// Toggle notifications for a specific star
  Future<void> toggleStarNotifications(String starId, bool enabled) async {
    final index = _savedStars.indexWhere((s) => s.id == starId);
    if (index == -1) return;

    _savedStars[index] = _savedStars[index].copyWith(
      notificationsEnabled: enabled,
    );
    notifyListeners();
    await _save();
  }

  /// Update a star's data
  Future<void> updateStar(SavedStar star) async {
    final index = _savedStars.indexWhere((s) => s.id == star.id);
    if (index == -1) return;

    _savedStars[index] = star;
    notifyListeners();
    await _save();
  }
}
