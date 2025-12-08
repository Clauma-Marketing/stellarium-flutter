import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A search history entry
class SearchHistoryEntry {
  final String query;
  final DateTime searchedAt;

  SearchHistoryEntry({
    required this.query,
    DateTime? searchedAt,
  }) : searchedAt = searchedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'searchedAt': searchedAt.toIso8601String(),
    };
  }

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      query: json['query'] as String,
      searchedAt: json['searchedAt'] != null
          ? DateTime.parse(json['searchedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Service for managing search history
class SearchHistoryService {
  static const String _storageKey = 'search_history';
  static const int _maxEntries = 3;
  static SearchHistoryService? _instance;

  final List<SearchHistoryEntry> _history = [];
  bool _isLoaded = false;

  SearchHistoryService._();

  /// Get the singleton instance
  static SearchHistoryService get instance {
    _instance ??= SearchHistoryService._();
    return _instance!;
  }

  /// Get search history (most recent first)
  List<SearchHistoryEntry> get history => List.unmodifiable(_history);

  /// Check if loaded
  bool get isLoaded => _isLoaded;

  /// Load search history from storage
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _history.clear();
        _history.addAll(
          jsonList.map((json) => SearchHistoryEntry.fromJson(json as Map<String, dynamic>)),
        );
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading search history: $e');
      _isLoaded = true;
    }
  }

  /// Save to storage
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((entry) => entry.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  /// Add a search query to history
  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Remove existing entry with same query (case-insensitive)
    _history.removeWhere((e) => e.query.toLowerCase() == trimmed.toLowerCase());

    // Add to beginning
    _history.insert(0, SearchHistoryEntry(query: trimmed));

    // Keep only max entries
    while (_history.length > _maxEntries) {
      _history.removeLast();
    }

    await _save();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    _history.clear();
    await _save();
  }

  /// Remove a specific entry
  Future<void> removeEntry(String query) async {
    _history.removeWhere((e) => e.query == query);
    await _save();
  }
}
