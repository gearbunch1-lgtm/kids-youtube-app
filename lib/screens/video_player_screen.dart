import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pod_player/pod_player.dart';
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
  late PodPlayerController _controller;
  final YouTubeService _youtubeService = YouTubeService();
  final ScrollController _scrollController = ScrollController();

  late Video _currentVideo;
  List<Video> _relatedVideos = [];
  String? _nextPageToken;
  bool _isLoadingRelated = false;
  bool _hasMoreRelated = true;
  bool _hasAddedToHistory = false;
  bool _showEndScreen = false;
  String? _errorMessage;

  final GlobalKey _playerKey = GlobalKey();

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

    _currentVideo = widget.video;
    _initializePlayer();

    // Load related videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRelatedVideos();
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  /// Initialize player - try to get stream URL from backend first for instant playback
  void _initializePlayer() async {
    try {
      // Try to get direct stream URL from backend (instant playback!)
      final streamUrl = await _youtubeService.getStreamUrl(_currentVideo.id);

      if (streamUrl != null && mounted) {
        // Use direct stream URL for INSTANT playback!
        print('Using server-extracted stream URL for instant playback');
        _controller = PodPlayerController(
          playVideoFrom: PlayVideoFrom.network(streamUrl),
          podPlayerConfig: const PodPlayerConfig(
            autoPlay: true,
            isLooping: false,
            wakelockEnabled: true,
          ),
        )..initialise();
      } else if (mounted) {
        // Fallback to pod_player's YouTube extraction
        print('Fallback to YouTube URL extraction');
        _controller = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(_currentVideo.videoUrl),
          podPlayerConfig: const PodPlayerConfig(
            autoPlay: true,
            isLooping: false,
            videoQualityPriority: [360, 480, 720],
            wakelockEnabled: true,
          ),
        )..initialise();
      }

      if (mounted) {
        // Add listener for state changes
        _controller.addListener(_onPlayerStateChange);
      }
    } catch (e) {
      print('Error initializing player: $e');
      // Fallback to YouTube app
      if (mounted) {
        Future.delayed(Duration.zero, () => _openInYouTubeApp());
      }
    }
  }

  void _onPlayerStateChange() {
    if (!mounted) return;

    // Track when video starts playing (add to history)
    if (_controller.isVideoPlaying && !_hasAddedToHistory) {
      _hasAddedToHistory = true;
      Provider.of<HistoryProvider>(
        context,
        listen: false,
      ).addToHistory(_currentVideo);
    }

    // Check if video has ended
    if (_controller.isInitialised) {
      final position = _controller.currentVideoPosition;
      final duration = _controller.totalVideoLength;

      if (duration.inSeconds > 0 &&
          position.inSeconds >= duration.inSeconds - 1 &&
          !_showEndScreen) {
        setState(() {
          _showEndScreen = true;
        });

        // Auto-play next video after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _showEndScreen && _relatedVideos.isNotEmpty) {
            _playNextVideo();
          }
        });
      }
    }
  }

  void _playNextVideo() async {
    if (_relatedVideos.isEmpty) return;

    final nextVideo = _relatedVideos.first;

    setState(() {
      _currentVideo = nextVideo;
      _relatedVideos = [];
      _nextPageToken = null;
      _hasMoreRelated = true;
      _showEndScreen = false;
      _hasAddedToHistory = false;
    });

    // Try to get stream URL for instant playback
    final streamUrl = await _youtubeService.getStreamUrl(nextVideo.id);

    if (streamUrl != null && mounted) {
      // Use direct stream URL for instant playback
      _controller.changeVideo(
        playVideoFrom: PlayVideoFrom.network(streamUrl),
        playerConfig: const PodPlayerConfig(autoPlay: true),
      );
    } else if (mounted) {
      // Fallback to YouTube extraction
      _controller.changeVideo(
        playVideoFrom: PlayVideoFrom.youtube(nextVideo.videoUrl),
        playerConfig: const PodPlayerConfig(
          autoPlay: true,
          videoQualityPriority: [360, 480, 720],
        ),
      );
    }

    // Load new related videos
    _loadRelatedVideos();
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
      final searchQuery = _extractKeywords(_currentVideo.title);

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
          .where((v) => v.id != _currentVideo.id)
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
      final searchQuery = _extractKeywords(_currentVideo.title);

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
          .where((v) => v.id != _currentVideo.id)
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
    final uri = Uri.parse(_currentVideo.videoUrl);
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);
    final isBookmarked = bookmarkProvider.isBookmarked(_currentVideo.id);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1. Video Player with Loading Placeholder
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Show thumbnail as placeholder while loading
                  if (!_controller.isInitialised)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail background
                          Image.network(
                            _currentVideo.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black),
                          ),
                          // Dark overlay
                          Container(color: Colors.black54),
                          // Loading indicator
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading video...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Actual player (builds on top when ready)
                  PodVideoPlayer(
                    key: _playerKey,
                    controller: _controller,
                    alwaysShowProgressBar: false,
                    frameAspectRatio: 16 / 9,
                    videoTitle: Text(
                      _currentVideo.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    overlayBuilder: (options) {
                      return _CustomControls(
                        controller: _controller,
                        showEndScreen: _showEndScreen,
                        relatedVideos: _relatedVideos,
                        onPlayNext: _playNextVideo,
                        onReplay: () {
                          _controller.videoSeekTo(Duration.zero);
                          _controller.play();
                          setState(() {
                            _showEndScreen = false;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. Title and Info Section
            SliverToBoxAdapter(
              child: Container(
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
                            _currentVideo.title,
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
                            bookmarkProvider.toggleBookmark(_currentVideo);
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
            ),

            // 3. Similar Videos Header
            SliverToBoxAdapter(
              child: Padding(
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
            ),

            // 4. Video Grid
            if (_relatedVideos.isEmpty && _isLoadingRelated)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
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
                          style: Theme.of(context).textTheme.bodyLarge,
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
                ),
              )
            else if (_relatedVideos.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No similar videos found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600
                        ? 2
                        : 1,
                    childAspectRatio: MediaQuery.of(context).size.width > 600
                        ? 2.5
                        : 3.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final relatedVideo = _relatedVideos[index];
                    return CompactVideoCard(
                      video: relatedVideo,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          FadePageRoute(
                            page: VideoPlayerScreen(video: relatedVideo),
                          ),
                        );
                      },
                    );
                  }, childCount: _relatedVideos.length),
                ),
              ),

            // 5. Loading More Indicator
            if (_hasMoreRelated && !_relatedVideos.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _CustomControls extends StatefulWidget {
  final PodPlayerController controller;
  final bool showEndScreen;
  final List<Video> relatedVideos;
  final VoidCallback onPlayNext;
  final VoidCallback onReplay;

  const _CustomControls({
    required this.controller,
    required this.showEndScreen,
    required this.relatedVideos,
    required this.onPlayNext,
    required this.onReplay,
  });

  @override
  State<_CustomControls> createState() => _CustomControlsState();
}

class _CustomControlsState extends State<_CustomControls> {
  bool _isVisible = true;
  bool _isDragging = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
    _startHideTimer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  void didUpdateWidget(_CustomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showEndScreen != oldWidget.showEndScreen) {
      if (widget.showEndScreen) {
        // Stop hiding controls when end screen is shown
        setState(() {
          _isVisible = true;
        });
      } else {
        // Restart hide timer when end screen is hidden (replay)
        _startHideTimer();
      }
    }
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    // Don't hide if end screen is showing
    if (widget.showEndScreen) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted &&
          !_isDragging &&
          widget.controller.isVideoPlaying &&
          !widget.showEndScreen) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _toggleVisibility() {
    // Don't toggle if end screen is showing
    if (widget.showEndScreen) return;

    setState(() {
      _isVisible = !_isVisible;
    });
    if (_isVisible) {
      _startHideTimer();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show End Screen if active
    if (widget.showEndScreen && widget.relatedVideos.isNotEmpty) {
      return Container(
        color: Colors.black.withOpacity(0.9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes
            final isSmallScreen = constraints.maxHeight < 300;
            final imageHeight = isSmallScreen
                ? constraints.maxHeight * 0.25
                : 180.0;
            final titleStyle = TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
            );
            final headerStyle = TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
            );

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Up Next', style: headerStyle),
                    SizedBox(height: isSmallScreen ? 8 : 20),
                    // Next video preview
                    GestureDetector(
                      onTap: widget.onPlayNext,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.relatedVideos.first.thumbnailUrl,
                                height: imageHeight,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Text(
                              widget.relatedVideos.first.title,
                              style: titleStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (!isSmallScreen) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.relatedVideos.first.channelTitle,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: widget.onReplay,
                          icon: Icon(
                            Icons.replay,
                            size: isSmallScreen ? 18 : 24,
                          ),
                          label: Text(
                            'Replay',
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 24,
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: widget.onPlayNext,
                          icon: Icon(
                            Icons.play_arrow,
                            size: isSmallScreen ? 18 : 24,
                          ),
                          label: Text(
                            'Play Next',
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 24,
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // 2. Show Controls
    final isPlaying = widget.controller.isVideoPlaying;
    final position = widget.controller.currentVideoPosition;
    final duration = widget.controller.totalVideoLength;

    return GestureDetector(
      onTap: _toggleVisibility,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Dark overlay when controls are visible
          if (_isVisible) Container(color: Colors.black.withOpacity(0.4)),

          // Center Controls (Rewind, Play/Pause, Forward)
          if (_isVisible)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  IconButton(
                    iconSize: 40,
                    color: Colors.white,
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      final currentPos = widget.controller.currentVideoPosition;
                      final newPos = currentPos - const Duration(seconds: 10);
                      widget.controller.videoSeekTo(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                      _startHideTimer();
                    },
                  ),
                  const SizedBox(width: 20),
                  // Play/Pause
                  IconButton(
                    iconSize: 64,
                    color: Colors.white,
                    icon: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                        _startHideTimer();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  // Forward 10s
                  IconButton(
                    iconSize: 40,
                    color: Colors.white,
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      final currentPos = widget.controller.currentVideoPosition;
                      final total = widget.controller.totalVideoLength;
                      final newPos = currentPos + const Duration(seconds: 10);
                      widget.controller.videoSeekTo(
                        newPos > total ? total : newPos,
                      );
                      _startHideTimer();
                    },
                  ),
                ],
              ),
            ),

          // Speed Control (Top Right) - Commented out due to API uncertainty
          /*
          if (_isVisible)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<double>(
                  initialValue: _playbackSpeed,
                  tooltip: 'Playback Speed',
                  onSelected: (speed) {
                    setState(() {
                      _playbackSpeed = speed;
                    });
                    // widget.controller.setVideoPlayBackSpeed(speed);
                    _startHideTimer();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 1.0, child: Text('Normal')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          */

          // Bottom Controls
          if (_isVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    // Current Time
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),

                    // Seek Bar
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble().clamp(
                            0.0,
                            duration.inSeconds.toDouble(),
                          ),
                          min: 0.0,
                          max: duration.inSeconds.toDouble(),
                          activeColor: Colors.red,
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() {
                              _isDragging = true;
                            });
                          },
                          onChangeEnd: (value) {
                            _isDragging = false;
                            widget.controller.videoSeekTo(
                              Duration(seconds: value.toInt()),
                            );
                            _startHideTimer();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Total Duration
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),

                    // Fullscreen Button
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: () {
                        widget.controller
                            .enableFullScreen(); // Correct method to toggle fullscreen
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
