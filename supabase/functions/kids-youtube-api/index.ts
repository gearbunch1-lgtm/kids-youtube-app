import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// CORS headers
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VideoData {
    id: string
    title: string
    thumbnailUrl: string
    channelTitle: string
    publishedAt: string
    description: string
    category: string
    videoUrl: string
    duration: string | null
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const url = new URL(req.url)
        const path = url.pathname.replace('/kids-youtube-api', '')

        // Search endpoint
        if (path === '/api/search') {
            const query = url.searchParams.get('q') || ''
            const page = url.searchParams.get('page') || '1'
            const continuationToken = url.searchParams.get('continuation') || null

            if (!query) {
                return new Response(
                    JSON.stringify({ error: 'Query parameter "q" is required' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            const result = await searchVideos(query, parseInt(page), continuationToken)

            return new Response(
                JSON.stringify(result),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Channel endpoint
        if (path.startsWith('/api/channel/')) {
            const channelName = path.replace('/api/channel/', '')
            const page = url.searchParams.get('page') || '1'

            const result = await getChannelVideos(channelName, parseInt(page))

            return new Response(
                JSON.stringify(result),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Health check
        if (path === '/api/health') {
            return new Response(
                JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        return new Response(
            JSON.stringify({ error: 'Not found' }),
            { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

async function searchVideos(query: string, page: number, continuationToken: string | null): Promise<{ videos: VideoData[], nextPageToken?: string }> {
    try {
        console.log(`[Kids API] Searching for: ${query}, page: ${page}, continuation: ${continuationToken ? 'yes' : 'no'}`)


        // Use the query as-is - the Flutter app already provides category-specific queries
        const searchQuery = query
        console.log(`[Kids API] Search query: ${searchQuery}`)

        let searchResults

        if (continuationToken) {
            // Decode base64 continuation token
            const decodedToken = atob(continuationToken)
            console.log(`[Kids API] Using decoded continuation token`)
            searchResults = await fetchYouTubeSearchContinuation(decodedToken, 150)
        } else {
            // Fresh search for first page
            searchResults = await fetchYouTubeSearch(searchQuery, 150)
        }


        // Smart filtering: Block inappropriate content types while maintaining consistency
        // We fetch 150 videos, filter out bad content, should still get 100+ videos
        const videos = searchResults.items
            .filter((item: any) => item.type === 'video')
            .map((video: any) => {
                const durationSeconds = parseDuration(video.duration || '')
                const title = (video.title || '').toLowerCase()
                const description = (video.description || '').toLowerCase()
                const channel = (video.channelTitle || '').toLowerCase()
                const combinedText = `${title} ${description} ${channel}`

                // Comprehensive child-safety filtering
                // Block ANY content not appropriate for children
                const inappropriateKeywords = [
                    // Movies & TV Shows
                    'full movie', 'full film', 'película completa', 'فيلم كامل', 'film complet',
                    'tv show', 'tv series', 'episode', 'season', 'مسلسل', 'حلقة',
                    'netflix', 'disney+', 'hbo', 'prime video', 'hulu', 'apple tv',

                    // Adult & Mature Content
                    '18+', '16+', '13+', 'adult only', 'nsfw', 'explicit', 'mature',
                    'parental advisory', 'viewer discretion', 'not for kids',

                    // Violence & Horror
                    'horror', 'scary', 'violent', 'gore', 'blood', 'murder', 'kill',
                    'death', 'dead', 'zombie', 'ghost', 'demon', 'devil', 'evil',
                    'weapon', 'gun', 'knife', 'sword', 'fight', 'war', 'battle',
                    'shoot', 'attack', 'crime', 'criminal', 'prison', 'jail',

                    // Inappropriate Music & Entertainment
                    'rap battle', 'diss track', 'explicit lyrics', 'uncensored',
                    'music video', 'official video', 'vevo', 'lyric video',
                    'nightclub', 'party', 'drunk', 'alcohol', 'beer', 'wine',

                    // News & Politics (not for kids)
                    'breaking news', 'news report', 'أخبار', 'نشرة',
                    'politics', 'political', 'election', 'president', 'government',
                    'war', 'conflict', 'crisis', 'disaster', 'tragedy',

                    // Documentaries & Educational (adult-level)
                    'documentary', 'full documentary', 'وثائقي كامل', 'documental',
                    'investigation', 'expose', 'true story', 'real story',

                    // Gaming (violent/mature games)
                    'gta', 'grand theft auto', 'call of duty', 'fortnite',
                    'pubg', 'free fire', 'mortal kombat', 'resident evil',

                    // Pranks & Challenges (potentially dangerous)
                    'prank gone wrong', 'extreme challenge', 'dangerous',
                    'do not try', 'warning', 'injury', 'hospital',

                    // Romance & Dating (not for kids)
                    'dating', 'boyfriend', 'girlfriend', 'romance', 'love story',
                    'kiss', 'romantic', 'relationship', 'breakup',

                    // Conspiracy & Paranormal
                    'conspiracy', 'illuminati', 'alien', 'ufo', 'paranormal',
                    'haunted', 'possessed', 'curse', 'ritual',

                    // Social Media Drama
                    'drama', 'exposed', 'cancelled', 'controversy', 'scandal',
                    'beef', 'feud', 'diss', 'roast', 'reaction',

                    // Inappropriate Language Indicators
                    'cursing', 'swearing', 'profanity', 'bad words',
                    'bleeped', 'censored', 'uncut', 'raw',

                    // Clickbait & Sensational
                    'you won\'t believe', 'shocking', 'disturbing', 'graphic',
                    'warning graphic', 'viewer discretion advised'
                ]

                const hasInappropriate = inappropriateKeywords.some(keyword =>
                    combinedText.includes(keyword)
                )

                if (hasInappropriate) return null

                // Also filter by duration: skip very long videos (likely movies/docs)
                // and very short videos (likely ads/clips)
                if (durationSeconds < 60 || durationSeconds > 3600) return null

                return {
                    id: video.id,
                    title: video.title,
                    thumbnailUrl: video.thumbnail || `https://i.ytimg.com/vi/${video.id}/hqdefault.jpg`,
                    channelTitle: video.channelTitle || 'Unknown',
                    publishedAt: video.publishedTime || 'Recently',
                    description: video.description || '',
                    category: 'general',
                    videoUrl: `https://www.youtube.com/watch?v=${video.id}`,
                    duration: formatDuration(durationSeconds)
                }
            })
            .filter((v: any) => v !== null)

        console.log(`[Kids API] Filtered ${videos.length} kid-friendly videos`)

        // Return continuation token as nextPageToken (base64 encoded to pass in URL)
        const nextToken = searchResults.continuation
            ? btoa(searchResults.continuation)
            : undefined

        return {
            videos,
            nextPageToken: nextToken
        }
    } catch (error) {
        console.error('[Kids API] Search error:', error)
        throw error
    }
}

async function getChannelVideos(channelName: string, page: number): Promise<{ videos: VideoData[], nextPageToken?: string }> {
    try {
        console.log(`[Kids API] Fetching channel videos: ${channelName}, page: ${page}`)

        const searchQuery = `${channelName} "cartoon" "kids"`

        // Always do fresh search
        const searchResults = await fetchYouTubeSearch(searchQuery, 50)

        // Filter videos from the same channel
        const videos = searchResults.items
            .filter((item: any) => {
                if (item.type !== 'video') return false

                const itemChannel = (item.channelTitle || '').toLowerCase().trim()
                const targetChannel = channelName.toLowerCase().trim()

                const normalizedItem = itemChannel.replace(/[^\w\s]/g, '')
                const normalizedTarget = targetChannel.replace(/[^\w\s]/g, '')

                return normalizedItem === normalizedTarget ||
                    itemChannel === targetChannel ||
                    (normalizedItem.includes(normalizedTarget) && normalizedTarget.length > 5)
            })
            .map((video: any) => {
                const durationSeconds = parseDuration(video.duration || '')

                // 2-20 minutes
                if (durationSeconds < 120 || durationSeconds > 1200) return null

                return {
                    id: video.id,
                    title: video.title,
                    thumbnailUrl: video.thumbnail || `https://i.ytimg.com/vi/${video.id}/hqdefault.jpg`,
                    channelTitle: video.channelTitle || 'Unknown',
                    publishedAt: video.publishedTime || 'Recently',
                    description: video.description || '',
                    category: 'general',
                    videoUrl: `https://www.youtube.com/watch?v=${video.id}`,
                    duration: formatDuration(durationSeconds)
                }
            })
            .filter((v: any) => v !== null)

        console.log(`[Kids API] Found ${videos.length} videos from channel: ${channelName}`)

        return {
            videos,
            nextPageToken: videos.length > 0 ? (page + 1).toString() : undefined
        }
    } catch (error) {
        console.error('[Kids API] Channel videos error:', error)
        throw error
    }
}

// Fetch YouTube search results using internal API
async function fetchYouTubeSearch(query: string, limit: number): Promise<any> {
    const response = await fetch('https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            context: {
                client: {
                    clientName: 'WEB',
                    clientVersion: '2.20231219.01.00',
                },
            },
            query,
        }),
    })

    const data = await response.json()
    return parseYouTubeResponse(data, limit)
}

async function fetchYouTubeSearchContinuation(continuation: string, limit: number): Promise<any> {
    const response = await fetch('https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            context: {
                client: {
                    clientName: 'WEB',
                    clientVersion: '2.20231219.01.00',
                },
            },
            continuation,
        }),
    })

    const data = await response.json()
    return parseYouTubeResponse(data, limit)
}

function parseYouTubeResponse(data: any, limit: number): any {
    const items: any[] = []
    let continuation = null

    const contents = data?.contents?.twoColumnSearchResultsRenderer?.primaryContents?.sectionListRenderer?.contents ||
        data?.onResponseReceivedCommands?.[0]?.appendContinuationItemsAction?.continuationItems || []

    for (const content of contents) {
        const itemSection = content.itemSectionRenderer
        if (itemSection) {
            for (const item of itemSection.contents || []) {
                if (items.length >= limit) break

                const videoRenderer = item.videoRenderer
                if (videoRenderer) {
                    items.push({
                        type: 'video',
                        id: videoRenderer.videoId,
                        title: videoRenderer.title?.runs?.[0]?.text || '',
                        thumbnail: videoRenderer.thumbnail?.thumbnails?.[0]?.url || '',
                        channelTitle: videoRenderer.ownerText?.runs?.[0]?.text || '',
                        publishedTime: videoRenderer.publishedTimeText?.simpleText || '',
                        description: videoRenderer.descriptionSnippet?.runs?.map((r: any) => r.text).join('') || '',
                        duration: videoRenderer.lengthText?.simpleText || '',
                    })
                }
            }
        }

        const continuationItemRenderer = content.continuationItemRenderer
        if (continuationItemRenderer) {
            continuation = continuationItemRenderer.continuationEndpoint?.continuationCommand?.token
        }
    }

    return { items, continuation }
}

function parseDuration(duration: string): number {
    if (!duration) return 0

    const parts = duration.split(':').map(p => parseInt(p) || 0)
    if (parts.length === 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    } else if (parts.length === 2) {
        return parts[0] * 60 + parts[1]
    }

    return 0
}

function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60

    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`
}
