# Supabase Setup Guide

## Prerequisites
- Supabase account
- GitHub repository

## Setup Steps

### 1. Create Supabase Project
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project
3. Note your **Project Reference ID** (from project URL)

### 2. Get Supabase Access Token
1. Go to [Supabase Access Tokens](https://supabase.com/dashboard/account/tokens)
2. Generate a new token and save it

### 3. Configure GitHub Secrets
Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:
- `SUPABASE_PROJECT_ID` - Your project reference ID
- `SUPABASE_ACCESS_TOKEN` - Your Supabase access token

### 4. Deploy
Push to `main` branch or manually trigger the workflow from Actions tab.

### 5. Update Flutter App
After deployment, update the backend URL in `lib/services/youtube_service.dart`:

```dart
static const String _backendUrl = 'https://YOUR-PROJECT-REF.supabase.co/functions/v1/kids-youtube-api';
```

Replace `YOUR-PROJECT-REF` with your actual Supabase project reference ID.

## Testing
Test the Edge Function:
```bash
curl "https://YOUR-PROJECT-REF.supabase.co/functions/v1/kids-youtube-api/api/search?q=peppa+pig"
```
