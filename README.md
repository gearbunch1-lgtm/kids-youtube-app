# Kids YouTube App

A Flutter mobile application for children that fetches and displays YouTube content, organized by kid-friendly categories.

## Features

- 🎨 **Colorful, Kid-Friendly UI** - Vibrant colors, playful fonts, and engaging design
- 📱 **Category Browsing** - 8 kid-friendly categories (Educational, Stories, Arts & Crafts, Music, Animals, Games, Cartoons, Sports)
- 🔍 **Search Functionality** - Search for specific videos
- ❤️ **Favorites** - Save favorite videos for easy access
- 🌓 **Dark Mode** - Toggle between light and dark themes
- ♾️ **Infinite Scroll** - Automatically load more videos as you scroll
- 🔄 **Pull to Refresh** - Refresh video list with a simple pull gesture
- 🎥 **YouTube Player** - Watch videos directly in the app
- 🔒 **Kid-Safe Content** - Strict safe search filtering and duration limits (2-20 minutes)
- ⚡ **Unlimited Content** - Uses backend proxy server (no YouTube API quota limits!)

## Architecture

This app uses the **same backend proxy approach** as the medical lectures web app:

```
Flutter App (Mobile) → Backend API (Node.js) → YouTube (unlimited)
```

**Benefits:**
- ✅ No YouTube API key needed
- ✅ Unlimited searches (bypasses quota limits)
- ✅ Same technology as medical lectures app
- ✅ Easy to deploy and maintain

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Node.js (for backend API)
- Android Studio / Xcode for mobile development

### Installation

#### 1. Install Flutter Dependencies

```bash
cd kids_youtube_app
flutter pub get
```

#### 2. Install Backend Dependencies

```bash
cd api
npm install
```

### Running the App

#### Step 1: Start the Backend API

```bash
cd api
npm run dev
```

The backend will run on `http://localhost:3002`

You should see:
```
🚀 Kids YouTube API running on http://localhost:3002
📝 Search endpoint: http://localhost:3002/api/search?q=animals
🎯 Filters: 2-20min duration, kid-friendly content only
♾️  Pagination: Unlimited results with youtube-search-api
```

#### Step 2: Run the Flutter App

In a new terminal:

```bash
cd kids_youtube_app
flutter run
```

The app will connect to the backend and fetch real YouTube videos!

### Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Project Structure

```
kids_youtube_app/
├── api/                  # Backend proxy server (Node.js)
│   ├── index.js         # Express server with youtube-search-api
│   ├── package.json     # Backend dependencies
│   └── README.md        # Backend documentation
├── lib/
│   ├── models/          # Data models (Video, Category)
│   ├── services/        # API services and mock data
│   │   └── youtube_service.dart  # Connects to backend API
│   ├── providers/       # State management (Provider pattern)
│   ├── screens/         # UI screens
│   ├── widgets/         # Reusable widgets
│   ├── theme/           # App theming and colors
│   └── main.dart        # App entry point
├── assets/
│   ├── images/
│   └── icons/
└── pubspec.yaml
```

## Categories

- 🎓 **Educational** - Science, Math, History
- 📚 **Stories & Tales** - Fairy tales, bedtime stories
- 🎨 **Arts & Crafts** - Drawing, DIY projects
- 🎵 **Music & Songs** - Kids songs, nursery rhymes
- 🐾 **Animals & Nature** - Wildlife, pets, environment
- 🎮 **Fun & Games** - Puzzles, brain teasers
- 📺 **Cartoons** - Educational cartoons
- ⚽ **Sports & Activities** - Kids sports, exercises

## Backend API

The backend uses `youtube-search-api` (same as medical lectures app) to:
- Bypass YouTube API quota limits
- Provide unlimited searches
- Filter content for kids (2-20 minute videos)
- Add kid-friendly keywords to searches

See [api/README.md](api/README.md) for backend documentation.

## Deployment

### Deploy Backend

Deploy the `api/` folder to:
- **Vercel** (recommended)
- **Railway**
- **Render**
- **Heroku**

### Update Flutter App

After deploying backend, update `lib/services/youtube_service.dart`:

```dart
static const String _backendUrl = 'https://your-deployed-backend.vercel.app';
```

Then build and deploy the Flutter app to app stores.

## Dependencies

### Flutter
- `provider` - State management
- `http` - HTTP requests
- `shared_preferences` - Local storage
- `youtube_player_flutter` - YouTube video playback
- `cached_network_image` - Image caching
- `google_fonts` - Custom fonts (Fredoka, Quicksand)
- `intl` - Date formatting

### Backend (Node.js)
- `express` - Web server
- `cors` - CORS support
- `youtube-search-api` - YouTube search without API key

## Safety Features

- Strict safe search enabled on all YouTube queries
- Video duration filtering (2-20 minutes ideal for kids)
- Kid-friendly keyword filtering
- No external links or ads
- Parental-friendly settings screen

## Comparison with Medical Lectures App

| Feature | Medical App | Kids App |
|---------|------------|----------|
| **Platform** | React (Web) | Flutter (Mobile) |
| **Backend** | Port 3001 | Port 3002 |
| **Search Query** | "+ medical lecture" | "+ kids" |
| **Duration** | 5+ minutes | 2-20 minutes |
| **Keywords** | Medical terms | Kid-friendly terms |
| **Target** | Medical students | Children |

Both apps use the **same backend technology** (youtube-search-api) for unlimited content!

## License

This project is created for educational purposes.

## Support

For questions or issues, please refer to the Help & Support section in the app settings.
