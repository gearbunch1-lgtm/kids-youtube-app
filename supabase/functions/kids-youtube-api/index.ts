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

// Cache for continuation tokens
const searchCache = new Map<string, any>()

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

            if (!query) {
                return new Response(
                    JSON.stringify({ error: 'Query parameter "q" is required' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            const result = await searchVideos(query, parseInt(page))

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

async function searchVideos(query: string, page: number): Promise<{ videos: VideoData[], nextPageToken?: string }> {
    try {
        console.log(`[Kids API] Searching for: ${query}, page: ${page}`)

        // Prioritize Arabic cartoon content
        const searchQuery = 'رسوم متحركة للأطفال كرتون ' + query + ' cartoon kids'
        console.log(`[Kids API] Enhanced search query: ${searchQuery}`)

        let searchResults
        const cacheKey = `${query}_continuation`

        if (page === 1) {
            // Fresh search for page 1
            searchResults = await fetchYouTubeSearch(searchQuery, 75)

            // Cache continuation token
            if (searchResults.continuation) {
                searchCache.set(cacheKey, searchResults.continuation)
            }
        } else {
            // Use continuation token for subsequent pages
            const continuation = searchCache.get(cacheKey)
            if (continuation) {
                searchResults = await fetchYouTubeSearchContinuation(continuation, 50)

                // Update cache
                if (searchResults.continuation) {
                    searchCache.set(cacheKey, searchResults.continuation)
                }
            } else {
                return { videos: [] }
            }
        }

        // Kid-friendly keywords
        const kidsKeywords = [
            'kids', 'children', 'educational', 'learning', 'fun', 'cartoon',
            'animation', 'story', 'tales', 'nursery', 'rhyme', 'song',
            'craft', 'art', 'draw', 'animal', 'nature', 'science',
            'math', 'abc', 'numbers', 'colors', 'shapes', 'family',
            'friendly', 'toddler', 'preschool', 'kindergarten',
            'أطفال', 'للأطفال', 'رسوم', 'متحركة', 'كرتون', 'تعليمي',
            'قصص', 'أغاني', 'حكايات', 'تلوين', 'حيوانات'
        ]

        // Filter and format videos
        const videos = searchResults.items
            .filter((item: any) => item.type === 'video')
            .map((video: any) => {
                const durationSeconds = parseDuration(video.duration || '')

                // Must be between 1-30 minutes
                if (durationSeconds < 60 || durationSeconds > 1800) return null

                const title = (video.title || '').toLowerCase()
                const description = (video.description || '').toLowerCase()
                const channel = (video.channelTitle || '').toLowerCase()
                const combinedText = `${title} ${description} ${channel}`

                // Must contain kid-friendly keyword
                const hasRelevantKeyword = kidsKeywords.some(keyword =>
                    combinedText.includes(keyword.toLowerCase())
                )

                if (!hasRelevantKeyword) return null

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

        return {
            videos,
            nextPageToken: searchResults.continuation ? (page + 1).toString() : undefined
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
        let searchResults
        const cacheKey = `${channelName}_channel_continuation`

        if (page === 1) {
            searchResults = await fetchYouTubeSearch(searchQuery, 50)

            if (searchResults.continuation) {
                searchCache.set(cacheKey, searchResults.continuation)
            }
        } else {
            const continuation = searchCache.get(cacheKey)
            if (continuation) {
                searchResults = await fetchYouTubeSearchContinuation(continuation, 50)

                if (searchResults.continuation) {
                    searchCache.set(cacheKey, searchResults.continuation)
                }
            } else {
                return { videos: [] }
            }
        }

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
            nextPageToken: searchResults.continuation ? (page + 1).toString() : undefined
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
