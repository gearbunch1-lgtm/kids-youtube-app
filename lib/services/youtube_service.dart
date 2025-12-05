import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import 'mock_data.dart';

class YouTubeService {
  // Backend API URL - using Supabase Edge Function (unlimited, no API key needed!)
  // Deployed via GitHub Actions to Supabase
  static const String _backendUrl =
      'https://kivsnvphztbywnwlffmb.supabase.co/functions/v1/kids-youtube-api';

  /// Get direct stream URL for a video (for instant playback)
  /// Returns null if extraction fails - caller should fallback to YouTube URL
  Future<String?> getStreamUrl(String videoId) async {
    try {
      final url = Uri.parse('$_backendUrl/api/stream/$videoId');
      print('Fetching stream URL: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Stream URL request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final streamUrl = data['streamUrl'] as String?;
        if (streamUrl != null) {
          print('Got stream URL for $videoId');
          return streamUrl;
        }
      }
      print('Failed to get stream URL: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error getting stream URL: $e');
      return null;
    }
  }

  // Search for videos using backend proxy (unlimited, no API key needed!)
  Future<Map<String, dynamic>> searchVideos(
    String query, {
    String? pageToken,
    int maxResults = 50,
  }) async {
    try {
      // Build query parameters
      final Map<String, String> params = {'q': query};

      // If we have a pageToken, it's actually a continuation token (base64 encoded)
      if (pageToken != null && pageToken != '1') {
        params['continuation'] = pageToken;
      }
      params['page'] = pageToken ?? '1';

      final url = Uri.parse(
        '$_backendUrl/api/search',
      ).replace(queryParameters: params);

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
    // Map category IDs to kid-friendly search terms with explicit child-safety keywords
    // Adding "kids" ensures YouTube's algorithm returns child-appropriate content
    final categoryQueries = {
      'educational':
          'kids تعليمي للأطفال educational learning children cartoon',
      'stories': 'kids قصص أطفال حكايات stories children cartoon',
      'arts': 'kids رسم تلوين للأطفال arts crafts children cartoon',
      'music': 'kids أغاني أطفال songs nursery rhymes children cartoon',
      'animals': 'kids حيوانات للأطفال animals children cartoon',
      'games': 'kids ألعاب أطفال games puzzles children cartoon',
      'cartoons': 'kids رسوم متحركة كرتون أطفال children بالعربي cartoon',
      'sports': 'kids رياضة أطفال sports exercise children cartoon',
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
