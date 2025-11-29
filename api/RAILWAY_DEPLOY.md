# Deploy Kids YouTube API to Railway (Free Tier)

## Railway Free Tier Deployment via Web Interface

Railway's free tier works through their web interface. Here's how to deploy:

### Step 1: Prepare Your Code

Your code is ready! The `api` folder contains everything needed.

### Step 2: Deploy via Railway Web Interface

1. **Go to your Railway project:**
   - Open: https://railway.com/project/fd281074-b346-4b9e-99f6-9ad03835a338

2. **Add a service:**
   - Click "+ New Service"
   - Select "Empty Service"

3. **Configure the service:**
   - Click on the new service
   - Go to "Settings" tab
   - Under "Source", click "Connect Repo" or "Deploy from Local Directory"

4. **Upload your code:**
   - If using GitHub: Connect your repo and select the `api` folder
   - If uploading directly: Use the Railway CLI to link (already done with `railway init`)

5. **Set the start command:**
   - In Settings → Deploy
   - Start Command: `npm start`
   - Root Directory: Leave blank (we're already in the api folder)

6. **Deploy:**
   - Railway will automatically build and deploy
   - Wait for deployment to complete

### Step 3: Get Your Public URL

1. In your Railway service, go to "Settings"
2. Scroll to "Networking"
3. Click "Generate Domain"
4. Copy the URL (e.g., `https://fearless-magic.up.railway.app`)

### Alternative: Use Render (Free Tier)

Since Railway CLI requires a paid plan, here's an easier free alternative:

1. **Go to Render.com:**
   - Visit: https://render.com
   - Sign up/Login

2. **Create New Web Service:**
   - Click "New +" → "Web Service"
   - Connect your GitHub repo (or use "Deploy from Git URL")

3. **Configure:**
   - Name: `kids-youtube-api`
   - Root Directory: `api`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Plan: **Free**

4. **Deploy:**
   - Click "Create Web Service"
   - Wait for deployment (2-3 minutes)
   - Copy your URL (e.g., `https://kids-youtube-api.onrender.com`)

## After Deployment

Update your Flutter app with the deployed URL:

```dart
// In lib/services/youtube_service.dart
static const String _backendUrl = 'YOUR_DEPLOYED_URL';
```

Then rebuild your Flutter app!
