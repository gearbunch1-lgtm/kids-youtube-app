import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../services/storage_service.dart';

class BookmarkProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<Video> _bookmarks = [];
  bool _isLoaded = false;

  List<Video> get bookmarks => _bookmarks;
  bool get isLoaded => _isLoaded;

  // Load bookmarks from storage
  Future<void> loadBookmarks() async {
    if (_isLoaded) return;
    
    _bookmarks = await _storageService.loadBookmarks();
    _isLoaded = true;
    notifyListeners();
  }

  // Add a bookmark
  Future<void> addBookmark(Video video) async {
    if (!_bookmarks.any((v) => v.id == video.id)) {
      _bookmarks.add(video);
      await _storageService.saveBookmarks(_bookmarks);
      notifyListeners();
    }
  }

  // Remove a bookmark
  Future<void> removeBookmark(String videoId) async {
    _bookmarks.removeWhere((v) => v.id == videoId);
    await _storageService.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  // Check if a video is bookmarked
  bool isBookmarked(String videoId) {
    return _bookmarks.any((v) => v.id == videoId);
  }

  // Toggle bookmark
  Future<void> toggleBookmark(Video video) async {
    if (isBookmarked(video.id)) {
      await removeBookmark(video.id);
    } else {
      await addBookmark(video);
    }
  }

  // Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    _bookmarks.clear();
    await _storageService.saveBookmarks(_bookmarks);
    notifyListeners();
  }
}
