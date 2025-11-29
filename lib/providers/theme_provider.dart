import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _isDarkMode = false;
  bool _isLoaded = false;

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;

  // Load theme preference
  Future<void> loadThemePreference() async {
    if (_isLoaded) return;
    
    _isDarkMode = await _storageService.loadThemePreference();
    _isLoaded = true;
    notifyListeners();
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.saveThemePreference(_isDarkMode);
    notifyListeners();
  }

  // Set theme explicitly
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _storageService.saveThemePreference(_isDarkMode);
    notifyListeners();
  }
}
