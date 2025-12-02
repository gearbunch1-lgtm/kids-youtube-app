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

        // Kid-friendly keywords - make it more lenient
        const kidsKeywords = [
            'kids', 'children', 'educational', 'learning', 'fun', 'cartoon',
            'animation', 'story', 'tales', 'nursery', 'rhyme', 'song',
            'craft', 'art', 'draw', 'animal', 'nature', 'science',
            'math', 'abc', 'numbers', 'colors', 'shapes', 'family',
            'friendly', 'toddler', 'preschool', 'kindergarten',
            'أطفال', 'للأطفال', 'رسوم', 'متحركة', 'كرتون', 'تعليمي',
            'قصص', 'أغاني', 'حكايات', 'تلوين', 'حيوانات', 'baby', 'play'
        ]

        // Filter and format videos - be more lenient with filtering
        const videos = searchResults.items
            .filter((item: any) => item.type === 'video')
            .map((video: any) => {
                const durationSeconds = parseDuration(video.duration || '')

                // Duration filter: 2 minutes to 45 minutes
                if (durationSeconds < 120 || durationSeconds > 2700) return null

                const title = (video.title || '').toLowerCase()
                const description = (video.description || '').toLowerCase()
                const channel = (video.channelTitle || '').toLowerCase()
                const combinedText = `${title} ${description} ${channel}`

                // CHILD SAFETY: Filter out inappropriate content
                const unsafeKeywords = [
                    '18+', 'adult only', 'nsfw', 'explicit', 'mature',
                    'horror', 'scary', 'violent', 'gore', 'blood',
                    'weapon', 'gun', 'knife', 'fight', 'war'
                ]

                const hasUnsafeContent = unsafeKeywords.some(keyword =>
                    combinedText.includes(keyword)
                )

                if (hasUnsafeContent) return null

                // CHILD SAFETY: Require kid-friendly indicators
                // Expanded list to catch more legitimate content
                const kidFriendlyKeywords = [
                    // English
                    'kids', 'children', 'child', 'educational', 'learning', 'learn',
                    'fun', 'cartoon', 'animation', 'animated', 'story', 'stories',
                    'tales', 'nursery', 'rhyme', 'song', 'music', 'sing',
                    'craft', 'art', 'draw', 'paint', 'color', 'animal', 'nature',
                    'science', 'math', 'abc', 'alphabet', 'numbers', 'counting',
                    'shapes', 'family', 'friendly', 'toddler', 'preschool',
                    'kindergarten', 'baby', 'play', 'game', 'puzzle', 'toy',
                    'teach', 'tutorial', 'lesson', 'school', 'student',
                    // Arabic
                    'أطفال', 'للأطفال', 'طفل', 'رسوم', 'متحركة', 'كرتون',
                    'تعليمي', 'تعليم', 'قصص', 'قصة', 'أغاني', 'أغنية',
                    'حكايات', 'تلوين', 'حيوانات', 'حيوان', 'لعب', 'لعبة',
                    'مدرسة', 'درس', 'دروس'
                ]

                const hasKidFriendlyContent = kidFriendlyKeywords.some(keyword =>
                    combinedText.includes(keyword.toLowerCase())
                )

                // Require kid-friendly content for safety
                if (!hasKidFriendlyContent) return null

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
