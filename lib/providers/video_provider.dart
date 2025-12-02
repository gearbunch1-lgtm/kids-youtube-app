import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../models/category_model.dart' as cat;
import '../services/youtube_service.dart';
import '../services/storage_service.dart';

class VideoProvider with ChangeNotifier {
  final YouTubeService _youtubeService = YouTubeService();
  final StorageService _storageService = StorageService();

  List<Video> _videos = []; // For search results or specific category view
  final Map<String, List<Video>> _categoryVideos =
      {}; // For home screen sections
  bool _isLoading = false;
  String? _nextPageToken;
  cat.Category? _selectedCategory;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  String? _error;

  List<Video> get videos => _videos;
  Map<String, List<Video>> get categoryVideos => _categoryVideos;
  bool get isLoading => _isLoading;
  bool get hasMore => _nextPageToken != null;
  cat.Category? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<String> get searchHistory => _searchHistory;
  String? get error => _error;

  // Load initial videos (Home Screen content)
  Future<void> loadInitialVideos() async {
    _isLoading = true;
    _searchQuery = '';
    _selectedCategory = null;
    _error = null;
    notifyListeners();

    try {
      // Load search history
      _searchHistory = await _storageService.loadSearchHistory();

      // 1. Load from cache first for instant UI
      await Future.wait(
        cat.kidsCategories.map((category) async {
          final cachedVideos = await _storageService.loadCategoryVideos(
            category.id,
          );
          if (cachedVideos.isNotEmpty) {
            _categoryVideos[category.id] = cachedVideos;
          }
        }),
      );

      // If we have cached data, stop loading indicator but continue fetching in background
      if (_categoryVideos.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
      }

      // 2. Fetch fresh data from API
      await Future.wait(
        cat.kidsCategories.map((category) async {
          try {
            final result = await _youtubeService.getVideosByCategory(
              category.id,
            );
            final videos = result['videos'] as List<Video>;

            if (videos.isNotEmpty) {
              _categoryVideos[category.id] = videos;
              // 3. Update cache
              await _storageService.saveCategoryVideos(category.id, videos);
            }
          } catch (e) {
            print('Error loading videos for category ${category.name}: $e');
            // Don't set global error here to avoid blocking the whole UI if one category fails
          }
        }),
      );
    } catch (e) {
      print('Error loading initial videos: $e');
      _error = 'Failed to load videos. Please check your internet connection.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load videos by category (View All / Filter)
  Future<void> loadVideosByCategory(cat.Category category) async {
    _selectedCategory = category;
    _searchQuery = '';
    _isLoading = true;
    _videos = [];
    _nextPageToken = null;
    _error = null;
    notifyListeners();

    try {
      final result = await _youtubeService.getVideosByCategory(category.id);
      _videos = result['videos'] as List<Video>;
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error loading category videos: $e');
      _error = 'Failed to load videos. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Search videos
  Future<void> searchVideos(String query) async {
    if (query.trim().isEmpty) return;

    _searchQuery = query;
    _selectedCategory = null;
    _isLoading = true;
    _videos = [];
    _nextPageToken = null;
    _error = null;
    notifyListeners();

    try {
      // Save to history
      if (!_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
        await _storageService.saveSearchHistory(_searchHistory);
      } else {
        // Move to top
        _searchHistory.remove(query);
        _searchHistory.insert(0, query);
        await _storageService.saveSearchHistory(_searchHistory);
      }

      final result = await _youtubeService.searchVideos(query);
      _videos = result['videos'] as List<Video>;
      _nextPageToken = result['nextPageToken'];

      if (_videos.isEmpty) {
        _error = 'No videos found for "$query"';
      }
    } catch (e) {
      print('Error searching videos: $e');
      _error = 'Failed to search videos. Please check your connection.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load more videos (pagination for search or specific category)
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
        return;
      }

      final newVideos = result['videos'] as List<Video>;
      _videos.addAll(newVideos);
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      print('Error loading more videos: $e');
      // Don't set main error for pagination failure, maybe show snackbar in UI
    }

    _isLoading = false;
    notifyListeners();
  }

  // Clear category filter
  void clearCategoryFilter() {
    _selectedCategory = null;
    _error = null;
    notifyListeners();
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _storageService.saveSearchHistory([]);
    notifyListeners();
  }

  // Remove single search item
  Future<void> removeSearchItem(String query) async {
    _searchHistory.remove(query);
    await _storageService.saveSearchHistory(_searchHistory);
    notifyListeners();
  }

  // Refresh videos
  Future<void> refresh() async {
    _error = null;
    if (_selectedCategory != null) {
      await loadVideosByCategory(_selectedCategory!);
    } else if (_searchQuery.isNotEmpty) {
      await searchVideos(_searchQuery);
    } else {
      await loadInitialVideos();
    }
  }
}
