import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_model.dart';
import '../providers/bookmark_provider.dart';
import '../providers/history_provider.dart';
import '../services/youtube_service.dart';
import '../widgets/compact_video_card.dart';
import '../utils/custom_route.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  final YouTubeService _youtubeService = YouTubeService();
  final ScrollController _scrollController = ScrollController();

  List<Video> _relatedVideos = [];
  String? _nextPageToken;
  bool _isLoadingRelated = false;
  bool _hasMoreRelated = true;
  bool _isPlayerReady = false;
  String? _errorMessage;
  PlayerState _playerState = PlayerState.unknown;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();

    // Allow all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Extract video ID from URL
    String? videoId;
    try {
      print('Video URL: ${widget.video.videoUrl}');
      videoId = YoutubePlayer.convertUrlToId(widget.video.videoUrl);
      print('Extracted video ID: $videoId');
    } catch (e) {
      print('Error parsing video URL: $e');
    }

    if (videoId == null || videoId.isEmpty) {
      print('WARNING: No valid video ID found!');
      // Fallback: Open in YouTube app immediately
      _openInYouTubeApp();
      return;
    }

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        controlsVisibleAtStart: false,
        disableDragSeek: true, // Prevent accidental seeking
        forceHD: false, // Allow adaptive quality for smoother playback
      ),
    )..addListener(_onPlayerStateChange);

    // Fallback: If player doesn't load within 5 seconds, open in YouTube app
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isPlayerReady && mounted) {
        print('Player failed to load, opening in YouTube app...');
        _openInYouTubeApp();
      }
    });

    // Load related videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRelatedVideos();
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  void _onPlayerStateChange() {
    if (_controller.value.isReady && !_isPlayerReady) {
      setState(() {
        _isPlayerReady = true;
      });
      // Add to history when video starts playing
      Provider.of<HistoryProvider>(
        context,
        listen: false,
      ).addToHistory(widget.video);
    }
    if (_controller.value.playerState != _playerState) {
      setState(() {
        _playerState = _controller.value.playerState;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoadingRelated && _hasMoreRelated) {
        _loadMoreRelatedVideos();
      }
    }
  }

  Future<void> _loadRelatedVideos() async {
    setState(() {
      _isLoadingRelated = true;
      _errorMessage = null;
    });

    try {
      // Extract keywords from video title for topic-based recommendations
      final searchQuery = _extractKeywords(widget.video.title);

      final result = await _youtubeService
          .searchVideos(searchQuery)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your connection.',
              );
            },
          );

      final videos = result['videos'] as List<Video>;
      // Filter out the current video
      final filteredVideos = videos
          .where((v) => v.id != widget.video.id)
          .toList();

      setState(() {
        _relatedVideos = filteredVideos;
        _nextPageToken = result['nextPageToken'] as String?;
        _hasMoreRelated = _nextPageToken != null && filteredVideos.isNotEmpty;
        _isLoadingRelated = false;

        // Show message if no videos found
        if (filteredVideos.isEmpty) {
          _errorMessage = 'No similar videos found';
        }
      });
    } catch (e) {
      print('Error loading related videos: $e');
      setState(() {
        _isLoadingRelated = false;
        _errorMessage = e.toString().contains('timeout')
            ? 'Connection timeout. Please try again.'
            : 'Failed to load videos. Please try again.';
      });
    }
  }

  Future<void> _loadMoreRelatedVideos() async {
    if (_nextPageToken == null) return;

    setState(() {
      _isLoadingRelated = true;
    });

    try {
      final searchQuery = _extractKeywords(widget.video.title);

      final result = await _youtubeService
          .searchVideos(searchQuery, pageToken: _nextPageToken)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      final videos = result['videos'] as List<Video>;
      final filteredVideos = videos
          .where((v) => v.id != widget.video.id)
          .toList();

      setState(() {
        _relatedVideos.addAll(filteredVideos);
        _nextPageToken = result['nextPageToken'] as String?;
        _hasMoreRelated = _nextPageToken != null && filteredVideos.isNotEmpty;
        _isLoadingRelated = false;
      });
    } catch (e) {
      print('Error loading more related videos: $e');
      setState(() {
        _isLoadingRelated = false;
        _hasMoreRelated = false; // Stop trying to load more on error
      });
    }
  }

  // Extract keywords from video title for better recommendations
  String _extractKeywords(String title) {
    // Remove common words and keep meaningful keywords
    final stopWords = [
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
    ];
    final words = title.toLowerCase().split(RegExp(r'[\s\-\|]+'));
    final keywords = words
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .take(3)
        .join(' ');

    return keywords.isNotEmpty ? keywords : title.split(' ').take(3).join(' ');
  }

  // Fallback: Open video in external YouTube app
  Future<void> _openInYouTubeApp() async {
    final uri = Uri.parse(widget.video.videoUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Close this screen since video will open externally
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error opening YouTube app: $e');
    }
  }

  @override
  void dispose() {
    // Reset orientations to portrait only when leaving the video screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(widget.video.id);

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
        progressColors: ProgressBarColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        onEnded: (metaData) {
          setState(() {
            _playerState = PlayerState.ended;
          });
        },
      ),
      onEnterFullScreen: () {
        setState(() {
          _isFullScreen = true;
        });
      },
      onExitFullScreen: () {
        setState(() {
          _isFullScreen = false;
        });
      },
      builder: (context, player) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Fixed Video Player Area with Overlays
                // We use AspectRatio to maintain 16:9 for the player container
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      // The Player (passed from YoutubePlayerBuilder)
                      player,

                      // Custom Back Button
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),

                      // End Screen Overlay (only in fullscreen mode)
                      if (_playerState == PlayerState.ended && _isFullScreen)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.85),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Watch Next',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_relatedVideos.isNotEmpty)
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Show up to 2 videos
                                        for (
                                          var i = 0;
                                          i <
                                              (_relatedVideos.length > 2
                                                  ? 2
                                                  : _relatedVideos.length);
                                          i++
                                        )
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pushReplacement(
                                                    context,
                                                    FadePageRoute(
                                                      page: VideoPlayerScreen(
                                                        video:
                                                            _relatedVideos[i],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    AspectRatio(
                                                      aspectRatio: 16 / 9,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        child: Image.network(
                                                          _relatedVideos[i]
                                                              .thumbnailUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) => Container(
                                                                color: Colors
                                                                    .grey[800],
                                                                child: const Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _relatedVideos[i].title,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _controller.seekTo(Duration.zero);
                                    _controller.play();
                                    setState(() {
                                      _playerState = PlayerState.playing;
                                    });
                                  },
                                  icon: const Icon(Icons.replay),
                                  label: const Text('Replay'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Fixed Title and Info Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.video.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isBookmarked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isBookmarked ? Colors.red : null,
                            ),
                            onPressed: () {
                              bookmarkProvider.toggleBookmark(widget.video);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
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
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.video.duration!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                  ),
                ),

                // Scrollable Content Below
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Similar Videos Section Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.video_library,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Similar Videos',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),

                        // Compact Video List
                        if (_relatedVideos.isEmpty && _isLoadingRelated)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadRelatedVideos,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_relatedVideos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No similar videos found',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width > 600
                                        ? 2
                                        : 1,
                                    childAspectRatio:
                                        MediaQuery.of(context).size.width > 600
                                        ? 2.5
                                        : 3.5,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount:
                                  _relatedVideos.length +
                                  (_hasMoreRelated ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _relatedVideos.length) {
                                  // Loading indicator at the end
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final relatedVideo = _relatedVideos[index];
                                return CompactVideoCard(
                                  video: relatedVideo,
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      FadePageRoute(
                                        page: VideoPlayerScreen(
                                          video: relatedVideo,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
