import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart' as cat;
import '../providers/video_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/video_card.dart';
import '../widgets/fade_in_widget.dart';
import '../utils/responsive_grid.dart';

import 'video_player_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import '../utils/custom_route.dart';
import '../widgets/video_card_skeleton.dart';
import '../widgets/state_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final bookmarkProvider = Provider.of<BookmarkProvider>(
        context,
        listen: false,
      );
      final historyProvider = Provider.of<HistoryProvider>(
        context,
        listen: false,
      );

      videoProvider.loadInitialVideos();
      bookmarkProvider.loadBookmarks();
      historyProvider.loadHistory();
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      if (!videoProvider.isLoading && videoProvider.hasMore) {
        videoProvider.loadMoreVideos();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Provider.of<VideoProvider>(context, listen: false).searchVideos(query);
    }
  }

  Widget _buildHomeContent() {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        // Show search results or specific category if active
        if (videoProvider.searchQuery.isNotEmpty ||
            videoProvider.selectedCategory != null) {
          return _buildGridContent(videoProvider);
        }

        return RefreshIndicator(
          onRefresh: () => videoProvider.refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for videos...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          videoProvider.loadInitialVideos();
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
              ),

              // Recently Watched Section
              SliverToBoxAdapter(
                child: Consumer<HistoryProvider>(
                  builder: (context, historyProvider, _) {
                    if (historyProvider.history.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history,
                                color: Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recently Watched',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                      fontSize: 22,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 240,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: historyProvider.history.length,
                            itemBuilder: (context, index) {
                              final video = historyProvider.history[index];
                              return Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 12),
                                child: VideoCard(
                                  video: video,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      FadePageRoute(
                                        page: VideoPlayerScreen(video: video),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (videoProvider.isLoading &&
                  videoProvider.categoryVideos.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Header Skeleton
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 150,
                                      height: 24,
                                      color: Colors.grey[300],
                                    ),
                                  ],
                                ),
                              ),
                              // Video List Skeleton
                              SizedBox(
                                height: 240,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: 3,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: 200,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: const VideoCardSkeleton(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final category = cat.kidsCategories[index];
                    final videos =
                        videoProvider.categoryVideos[category.id] ?? [];

                    if (videos.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Row(
                            children: [
                              // Category Icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: category.color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Category Name
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: category.color,
                                        fontSize: 22,
                                      ),
                                ),
                              ),
                              // View All Button
                              InkWell(
                                onTap: () {
                                  videoProvider.loadVideosByCategory(category);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: category.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: category.color.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    'View All',
                                    style: TextStyle(
                                      color: category.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Horizontal Video List
                        SizedBox(
                          height: 240, // Reduced height for smaller cards
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: videos.length,
                            itemBuilder: (context, videoIndex) {
                              final video = videos[videoIndex];
                              return Container(
                                width: 200, // Reduced width from 260
                                margin: const EdgeInsets.only(right: 12),
                                child: VideoCard(
                                  video: video,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      FadePageRoute(
                                        page: VideoPlayerScreen(video: video),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }, childCount: cat.kidsCategories.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridContent(VideoProvider videoProvider) {
    return RefreshIndicator(
      onRefresh: () => videoProvider.refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search bar (same as above, could be extracted)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for videos...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      videoProvider.loadInitialVideos();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  filled: true,
                ),
                onSubmitted: (_) => _onSearch(),
              ),
            ),
          ),

          // Videos grid
          if (videoProvider.videos.isEmpty && !videoProvider.isLoading)
            SliverFillRemaining(
              child: StateView.empty(
                message: 'No videos found matching your search.',
                onAction: () {
                  _searchController.clear();
                  videoProvider.loadInitialVideos();
                },
                actionLabel: 'Clear Search',
              ),
            )
          else if (videoProvider.videos.isEmpty && videoProvider.isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: ResponsiveGrid.getGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const VideoCardSkeleton(),
                  childCount: 6,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: ResponsiveGrid.getGridDelegate(context),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final video = videoProvider.videos[index];
                  return VideoCard(
                    video: video,
                    onTap: () {
                      Navigator.push(
                        context,
                        FadePageRoute(page: VideoPlayerScreen(video: video)),
                      );
                    },
                  );
                }, childCount: videoProvider.videos.length),
              ),
            ),

          // Loading indicator for pagination
          if (videoProvider.isLoading && videoProvider.videos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: ResponsiveGrid.getGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const VideoCardSkeleton(),
                  childCount: 2,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeContent(),
      const FavoritesScreen(),
      const SettingsScreen(),
    ];

    return Consumer<VideoProvider>(
      builder: (context, videoProvider, _) {
        final bool showBackButton =
            videoProvider.selectedCategory != null ||
            videoProvider.searchQuery.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              showBackButton
                  ? (videoProvider.selectedCategory?.name ?? 'Search Results')
                  : 'Kids YouTube',
            ),
            centerTitle: true,
            leading: showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => videoProvider.clearCategoryFilter(),
                  )
                : null,
          ),
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
