import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class StorageService {
  static const String _bookmarksKey = 'kids_youtube_bookmarks';
  static const String _themeKey = 'kids_youtube_theme';
  static const String _historyKey = 'kids_youtube_history';

  // Save bookmarks
  Future<void> saveBookmarks(List<Video> bookmarks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = bookmarks.map((v) => v.toJson()).toList();
      await prefs.setString(_bookmarksKey, json.encode(bookmarksJson));
    } catch (e) {
      print('Error saving bookmarks: $e');
    }
  }

  // Load bookmarks
  Future<List<Video>> loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksString = prefs.getString(_bookmarksKey);
      
      if (bookmarksString != null) {
        final List<dynamic> bookmarksJson = json.decode(bookmarksString);
        return bookmarksJson.map((json) => Video.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading bookmarks: $e');
    }
    
    return [];
  }

  // Save theme preference (true = dark, false = light)
  Future<void> saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  // Load theme preference
  Future<bool> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_themeKey) ?? false; // Default to light theme
    } catch (e) {
      print('Error loading theme: $e');
      return false;
    }
  }

  // Save watch history
  Future<void> saveHistory(List<Video> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = history.map((v) => v.toJson()).toList();
      await prefs.setString(_historyKey, json.encode(historyJson));
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  // Load watch history
  Future<List<Video>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyKey);
      
      if (historyString != null) {
        final List<dynamic> historyJson = json.decode(historyString);
        return historyJson.map((json) => Video.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading history: $e');
    }
    
    return [];
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarksKey);
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}
