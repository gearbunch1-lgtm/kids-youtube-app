import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../models/video_model.dart';
import '../providers/bookmark_provider.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    // Extract video ID from URL
    String? videoId;
    try {
      final uri = Uri.parse(widget.video.videoUrl);
      if (uri.host.contains('youtu.be')) {
        videoId = uri.pathSegments.first;
      } else {
        videoId = uri.queryParameters['v'];
      }
    } catch (e) {
      print('Error parsing video URL: $e');
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId ?? '',
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(widget.video.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Video'),
        actions: [
          // Watch on YouTube button (backup)
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Watch on YouTube',
            onPressed: () {
              html.window.open(widget.video.videoUrl, '_blank');
            },
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.favorite : Icons.favorite_border,
              color: isBookmarked ? Colors.red : null,
            ),
            onPressed: () {
              bookmarkProvider.toggleBookmark(widget.video);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube Player
            YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),

            // Video info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.video.channelTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (widget.video.duration != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.video.duration!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description.isNotEmpty
                        ? widget.video.description
                        : 'No description available',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
