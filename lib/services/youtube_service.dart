import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import 'mock_data.dart';

class YouTubeService {
  // Backend API URL - using our Node.js proxy server for unlimited requests
  // Using localhost for now - deploy backend separately when ready
  static const String _backendUrl = 'http://localhost:3002';

  // Search for videos using backend proxy (unlimited, no API key needed!)
  Future<Map<String, dynamic>> searchVideos(
    String query, {
    String? pageToken,
    int maxResults = 20,
  }) async {
    try {
      final page = pageToken ?? '1';
      final url = Uri.parse(
        '$_backendUrl/api/search',
      ).replace(queryParameters: {'q': query, 'page': page});

      print('Fetching from backend: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = _parseVideosFromBackend(data['videos'] as List<dynamic>);

        print('Fetched ${videos.length} videos from backend');

        return {'videos': videos, 'nextPageToken': data['nextPageToken']};
      } else {
        print('Backend API Error: ${response.statusCode}');
        return _getMockSearchResults(query);
      }
    } catch (e) {
      print('Error fetching from backend: $e');
      print('Falling back to mock data');
      return _getMockSearchResults(query);
    }
  }

  // Get videos by category using backend
  Future<Map<String, dynamic>> getVideosByCategory(
    String category, {
    String? pageToken,
  }) async {
    // Map category IDs to kid-friendly search terms
    final categoryQueries = {
      'educational': 'educational kids science math',
      'stories': 'kids stories fairy tales',
      'arts': 'kids arts crafts drawing',
      'music': 'kids songs nursery rhymes',
      'animals': 'animals for kids wildlife',
      'games': 'kids games puzzles brain teasers',
      'cartoons': 'kids cartoons educational',
      'sports': 'kids sports exercise yoga',
    };

    final query = categoryQueries[category] ?? 'kids educational';
    return searchVideos(query, pageToken: pageToken);
  }

  // Parse videos from backend response
  List<Video> _parseVideosFromBackend(List<dynamic> videosData) {
    final List<Video> videos = [];

    for (var videoData in videosData) {
      try {
        // The backend already returns filtered videos in the correct format
        videos.add(
          Video(
            id: videoData['id'] as String,
            title: videoData['title'] as String,
            thumbnailUrl: videoData['thumbnailUrl'] as String,
            channelTitle: videoData['channelTitle'] as String,
            publishedAt: videoData['publishedAt'] as String,
            description: videoData['description'] as String,
            category: videoData['category'] as String? ?? 'general',
            videoUrl: videoData['videoUrl'] as String,
            duration: videoData['duration'] as String?,
          ),
        );
      } catch (e) {
        print('Error parsing video: $e');
      }
    }

    return videos;
  }

  // Fallback to mock data if backend is unavailable
  Map<String, dynamic> _getMockSearchResults(String query) {
    List<Video> filteredVideos;

    if (query.isEmpty) {
      filteredVideos = mockVideos;
    } else {
      filteredVideos = mockVideos.where((video) {
        final searchLower = query.toLowerCase();
        return video.title.toLowerCase().contains(searchLower) ||
            video.description.toLowerCase().contains(searchLower) ||
            video.category.toLowerCase().contains(searchLower);
      }).toList();
    }

    return {'videos': filteredVideos, 'nextPageToken': null};
  }
}
