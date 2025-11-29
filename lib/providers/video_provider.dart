import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../models/category_model.dart' as cat;
import '../services/youtube_service.dart';

class VideoProvider with ChangeNotifier {
  final YouTubeService _youtubeService = YouTubeService();
  
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _nextPageToken;
  cat.Category? _selectedCategory;
  String _searchQuery = '';

  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  bool get hasMore => _nextPageToken != null;
  cat.Category? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  // Load initial videos
  Future<void> loadInitialVideos() async {
    _isLoading = true;
    _videos = [];
    _nextPageToken = null;
    notifyListeners();

    try {
      final result = await _youtubeService.searchVideos('kids educational');
      _videos = result['videos'] as List<Video>;
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error loading videos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load videos by category
  Future<void> loadVideosByCategory(cat.Category category) async {
    _selectedCategory = category;
    _searchQuery = '';
    _isLoading = true;
    _videos = [];
    _nextPageToken = null;
    notifyListeners();

    try {
      final result = await _youtubeService.getVideosByCategory(category.id);
      _videos = result['videos'] as List<Video>;
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error loading category videos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Search videos
  Future<void> searchVideos(String query) async {
    _searchQuery = query;
    _selectedCategory = null;
    _isLoading = true;
    _videos = [];
    _nextPageToken = null;
    notifyListeners();

    try {
      final result = await _youtubeService.searchVideos(query);
      _videos = result['videos'] as List<Video>;
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error searching videos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load more videos (pagination)
  Future<void> loadMoreVideos() async {
    if (_isLoading || _nextPageToken == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      Map<String, dynamic> result;
      
      if (_selectedCategory != null) {
        result = await _youtubeService.getVideosByCategory(
          _selectedCategory!.id,
          pageToken: _nextPageToken,
        );
      } else if (_searchQuery.isNotEmpty) {
        result = await _youtubeService.searchVideos(
          _searchQuery,
          pageToken: _nextPageToken,
        );
      } else {
        result = await _youtubeService.searchVideos(
          'kids educational',
          pageToken: _nextPageToken,
        );
      }

      final newVideos = result['videos'] as List<Video>;
      _videos.addAll(newVideos);
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error loading more videos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Clear category filter
  void clearCategoryFilter() {
    _selectedCategory = null;
    loadInitialVideos();
  }

  // Refresh videos
  Future<void> refresh() async {
    if (_selectedCategory != null) {
      await loadVideosByCategory(_selectedCategory!);
    } else if (_searchQuery.isNotEmpty) {
      await searchVideos(_searchQuery);
    } else {
      await loadInitialVideos();
    }
  }
}
