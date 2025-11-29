# Kids YouTube API

Backend API for the Kids YouTube Flutter app. Provides YouTube search functionality with kid-friendly filtering.

## Features
- YouTube video search using `youtube-search-api`
- Kid-friendly content filtering
- Duration filtering (2-20 minutes)
- Pagination support
- CORS enabled

## API Endpoints

### Health Check
```
GET /api/health
```

### Search Videos
```
GET /api/search?q=<query>&page=<page_number>
```

**Parameters:**
- `q` (required): Search query
- `page` (optional): Page number for pagination (default: 1)

**Response:**
```json
{
  "videos": [...],
  "hasMore": true,
  "nextPage": 2
}
```

## Deployment

### Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Run: `vercel`
3. Follow prompts

### Railway
1. Connect GitHub repo
2. Select `api` directory as root
3. Deploy

### Render
1. Create new Web Service
2. Set root directory to `api`
3. Build command: `npm install`
4. Start command: `npm start`

## Local Development
```bash
npm install
npm start
```

Server runs on `http://localhost:3002`
