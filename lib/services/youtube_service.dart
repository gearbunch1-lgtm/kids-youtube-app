import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import 'mock_data.dart';

class YouTubeService {
  // Backend API URL - using our Node.js proxy server for unlimited requests
  // Production backend deployed on Render
  static const String _backendUrl = 'https://kids-youtube-app.onrender.com';
  // Backend API URL - using local server for testing fixes
  // Use 127.0.0.1:3002 with 'adb reverse tcp:3002 tcp:3002'
  // static const String _backendUrl = 'http://127.0.0.1:3002';

  // Search for videos using backend proxy (unlimited, no API key needed!)
  Future<Map<String, dynamic>> searchVideos(
    String query, {
    String? pageToken,
    int maxResults = 50,
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
    // Map category IDs to kid-friendly search terms with Arabic cartoon priority
    final categoryQueries = {
      'educational': 'تعليمي للأطفال educational cartoon',
      'stories': 'قصص أطفال حكايات stories cartoon',
      'arts': 'رسم تلوين للأطفال arts crafts cartoon',
      'music': 'أغاني أطفال songs nursery rhymes cartoon',
      'animals': 'حيوانات للأطفال animals cartoon',
      'games': 'ألعاب أطفال games puzzles cartoon',
      'cartoons': 'رسوم متحركة للأطفال كرتون cartoons',
      'sports': 'رياضة أطفال sports exercise cartoon',
    };

    final query = categoryQueries[category] ?? 'kids educational';
    return searchVideos(query, pageToken: pageToken);
  }

  // Get videos from a specific channel
  Future<Map<String, dynamic>> getChannelVideos(
    String channelName, {
    String? pageToken,
  }) async {
    try {
      final page = pageToken ?? '1';
      final url = Uri.parse(
        '$_backendUrl/api/channel/$channelName',
      ).replace(queryParameters: {'page': page});

      print('Fetching channel videos: $url');

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

        print('Fetched ${videos.length} videos from channel: $channelName');

        return {'videos': videos, 'nextPageToken': data['nextPageToken']};
      } else {
        print('Channel API Error: ${response.statusCode}');
        return {'videos': <Video>[], 'nextPageToken': null};
      }
    } catch (e) {
      print('Error fetching channel videos: $e');
      return {'videos': <Video>[], 'nextPageToken': null};
    }
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
