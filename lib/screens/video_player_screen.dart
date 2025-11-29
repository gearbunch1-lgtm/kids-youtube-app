import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/bookmark_provider.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(widget.video.id);

    // Construct the YouTube embed HTML
    // We use the embed URL which is standard for web
    final videoId = _extractVideoId(widget.video.videoUrl);
    final embedHtml = '''
      <iframe 
        width="100%" 
        height="100%" 
        src="https://www.youtube.com/embed/$videoId?autoplay=1&rel=0" 
        frameborder="0" 
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
        allowfullscreen>
      </iframe>
    ''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Video'),
        actions: [
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
            // Video Player Container
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: HtmlWidget(
                  embedHtml,
                  // Ensure we use a WebView (iframe) for the iframe tag
                  onLoadingBuilder: (context, element, loadingProgress) => 
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),

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

  String _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.first;
      } else if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v']!;
      }
    } catch (e) {
      print('Error parsing video URL: $e');
    }
    return '';
  }
}
