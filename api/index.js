const express = require('express');
const cors = require('cors');
const youtubeSearch = require('youtube-search-api');

const app = express();
const PORT = process.env.PORT || 3002; // Different port from medical app

// Enable CORS for all origins
app.use(cors());

// Cache for storing search continuation tokens
const searchCache = new Map();

// Helper function to convert seconds to readable duration format
const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
};

// Parse ISO 8601 duration (PT1H2M10S) or time string to seconds
const parseDuration = (duration) => {
    if (!duration) return 0;

    // Try ISO 8601 format first
    const isoMatch = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
    if (isoMatch) {
        const hours = parseInt(isoMatch[1] || 0);
        const minutes = parseInt(isoMatch[2] || 0);
        const seconds = parseInt(isoMatch[3] || 0);
        return hours * 3600 + minutes * 60 + seconds;
    }

    // Try simple time format (HH:MM:SS or MM:SS)
    const parts = duration.split(':').map(p => parseInt(p) || 0);
    if (parts.length === 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length === 2) {
        return parts[0] * 60 + parts[1];
    }

    return 0;
};

// Search endpoint for kids content
app.get('/api/search', async (req, res) => {
    try {
        const { q, page = 1 } = req.query;

        if (!q) {
            return res.status(400).json({ error: 'Query parameter "q" is required' });
        }

        console.log(`[Kids API] Searching for: ${q}, page: ${page}`);

        let searchResults;
        const pageNum = parseInt(page);

        // For page 1, do a fresh search
        if (pageNum === 1) {
            console.time('YouTube Search');
            // PRIORITIZE Arabic cartoon content by putting Arabic keywords FIRST
            // YouTube's algorithm gives more weight to earlier keywords
            const searchQuery = 'رسوم متحركة للأطفال كرتون ' + q + ' cartoon kids';
            console.log(`[Kids API] Enhanced search query: ${searchQuery}`);
            searchResults = await youtubeSearch.GetListByKeyword(searchQuery, false, 25);
            console.timeEnd('YouTube Search');

            // Cache the continuation token for next page
            if (searchResults.nextPage) {
                const cacheKey = `${q}_continuation`;
                searchCache.set(cacheKey, searchResults.nextPage);
            }
        } else {
            // For subsequent pages, use the continuation token
            const cacheKey = `${q}_continuation`;
            const continuation = searchCache.get(cacheKey);

            if (continuation) {
                searchResults = await youtubeSearch.NextPage(continuation, false, 50);
                // Update cache with new continuation token
                if (searchResults.nextPage) {
                    searchCache.set(cacheKey, searchResults.nextPage);
                }
            } else {
                // If no continuation token, return empty results
                return res.json({ videos: [], nextPageToken: undefined });
            }
        }

        // Kid-friendly keywords for relevance filtering (Arabic + English)
        const kidsKeywords = [
            // English keywords
            'kids', 'children', 'educational', 'learning', 'fun', 'cartoon',
            'animation', 'story', 'tales', 'nursery', 'rhyme', 'song',
            'craft', 'art', 'draw', 'animal', 'nature', 'science',
            'math', 'abc', 'numbers', 'colors', 'shapes', 'family',
            'friendly', 'toddler', 'preschool', 'kindergarten',
            // Arabic keywords for safety
            'أطفال', 'للأطفال', 'رسوم', 'متحركة', 'كرتون', 'تعليمي',
            'قصص', 'أغاني', 'حكايات', 'تلوين', 'حيوانات'
        ];

        // Filter and format videos
        const allVideos = (searchResults.items || [])
            .filter(item => item.type === 'video')
            .map(video => {
                // Parse duration from various possible fields
                const durationSeconds = parseDuration(
                    video.length?.simpleText ||
                    video.lengthText ||
                    video.duration ||
                    ''
                );

                const title = (video.title || '').toLowerCase();
                const description = (video.description || '').toLowerCase();
                const channel = (video.channelTitle || '').toLowerCase();

                // Must be between 2-20 minutes (120-1200 seconds) - ideal for kids
                if (durationSeconds < 120 || durationSeconds > 1200) return null;

                // Must contain at least one kid-friendly keyword
                const combinedText = `${title} ${description} ${channel}`;
                const hasRelevantKeyword = kidsKeywords.some(keyword =>
                    combinedText.includes(keyword.toLowerCase())
                );

                if (!hasRelevantKeyword) return null;

                return {
                    id: video.id,
                    title: video.title,
                    thumbnailUrl: video.thumbnail?.thumbnails?.[0]?.url || `https://i.ytimg.com/vi/${video.id}/hqdefault.jpg`,
                    channelTitle: video.channelTitle || 'Unknown',
                    publishedAt: video.publishedTime || 'Recently',
                    description: video.description || '',
                    category: 'general',
                    videoUrl: `https://www.youtube.com/watch?v=${video.id}`,
                    duration: formatDuration(durationSeconds)
                };
            })
            .filter(v => v !== null);

        console.log(`[Kids API] Filtered ${allVideos.length} kid-friendly videos (2-20min) from ${searchResults.items?.length || 0} total results`);

        // Return videos with nextPageToken if more pages available
        const nextPageToken = searchResults.nextPage ? (pageNum + 1).toString() : undefined;

        res.json({
            videos: allVideos,
            nextPageToken
        });

    } catch (error) {
        console.error('[Kids API] Search error:', error);
        res.status(500).json({
            error: 'Failed to search videos',
            message: error.message
        });
    }
});

// Get videos from a specific channel
app.get('/api/channel/:channelName', async (req, res) => {
    try {
        const { channelName } = req.params;
        const { page = 1 } = req.query;

        if (!channelName) {
            return res.status(400).json({ error: 'Channel name is required' });
        }

        console.log(`[Kids API] 📺 Fetching channel videos: ${channelName}, page: ${page}`);

        const pageNum = parseInt(page);
        let searchResults;

        // Search for videos from this channel - prioritize channel name
        // We use a simpler query to ensure we get more results from the actual channel
        const searchQuery = `${channelName} "cartoon" "kids"`;

        if (pageNum === 1) {
            // Increase initial fetch to 50 to have more candidates after filtering
            searchResults = await youtubeSearch.GetListByKeyword(searchQuery, false, 50);

            // Cache continuation token
            if (searchResults.nextPage) {
                const cacheKey = `${channelName}_channel_continuation`;
                searchCache.set(cacheKey, searchResults.nextPage);
            }
        } else {
            const cacheKey = `${channelName}_channel_continuation`;
            const continuation = searchCache.get(cacheKey);

            if (continuation) {
                searchResults = await youtubeSearch.NextPage(continuation, false, 50);
                if (searchResults.nextPage) {
                    searchCache.set(cacheKey, searchResults.nextPage);
                }
            } else {
                return res.json({ videos: [], nextPageToken: undefined });
            }
        }

        // Filter videos from the same channel
        const channelVideos = (searchResults.items || [])
            .filter(item => {
                if (item.type !== 'video') return false;

                const itemChannel = (item.channelTitle || '').toLowerCase();
                const targetChannel = channelName.toLowerCase();

                // Check if channel name matches
                return itemChannel.includes(targetChannel) || targetChannel.includes(itemChannel);
            })
            .map(video => {
                const durationSeconds = parseDuration(
                    video.length?.simpleText ||
                    video.lengthText ||
                    video.duration ||
                    ''
                );

                // Filter by duration (2-20 minutes)
                if (durationSeconds < 120 || durationSeconds > 1200) return null;

                return {
                    id: video.id,
                    title: video.title,
                    thumbnailUrl: video.thumbnail?.thumbnails?.[0]?.url || `https://i.ytimg.com/vi/${video.id}/hqdefault.jpg`,
                    channelTitle: video.channelTitle || 'Unknown',
                    publishedAt: video.publishedTime || 'Recently',
                    description: video.description || '',
                    category: 'general',
                    videoUrl: `https://www.youtube.com/watch?v=${video.id}`,
                    duration: formatDuration(durationSeconds)
                };
            })
            .filter(v => v !== null);

        console.log(`[Kids API] Found ${channelVideos.length} videos from channel: ${channelName}`);

        const nextPageToken = searchResults.nextPage ? (pageNum + 1).toString() : undefined;

        res.json({
            videos: channelVideos,
            nextPageToken
        });

    } catch (error) {
        console.error('[Kids API] Channel videos error:', error);
        res.status(500).json({
            error: 'Failed to fetch channel videos',
            message: error.message
        });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Kids YouTube API',
        endpoints: {
            search: '/api/search?q=query&page=1',
            health: '/api/health'
        },
        filters: {
            minDuration: '2 minutes',
            maxDuration: '20 minutes',
            contentType: 'Kid-friendly only'
        },
        features: {
            pagination: 'Unlimited results with youtube-search-api',
            resultsPerPage: '~50 videos (after filtering)'
        }
    });
});

// Export for Vercel serverless
module.exports = app;

// For local development
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`🚀 Kids YouTube API running on http://localhost:${PORT}`);
        console.log(`📝 Search endpoint: http://localhost:${PORT}/api/search?q=animals`);
        console.log(`🎯 Filters: 2-20min duration, kid-friendly content only`);
        console.log(`♾️  Pagination: Unlimited results with youtube-search-api`);
    });
}

