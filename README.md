# YT Mate

**Click Share, Get Smarter.**

YT Mate is an iOS app that transforms YouTube videos into actionable learning summaries using AI. Share a video, get an instant TL;DR with timestamped action items.

## Features

### Smart Importer
- **Share Extension**: Tap "Share" in YouTube → Select "YT Insights" → Get instant summary
- **Clipboard Detection**: Automatically detects YouTube URLs when you open the app
- **Deep Link Support**: Handle `ytmate://` URL schemes

### AI Content Engine
- **Powered by Gemini 3 Flash**: Sub-2-second latency, native video understanding
- **Structured Output**: Consistent JSON schema for reliable results
- **Generated Assets**:
  - 📝 **TL;DR**: 2-sentence high-level summary
  - ✅ **Action Plan**: 5-10 timestamped, actionable items
  - 🏷️ **Vibe Check**: Auto-categorization (Technical, Tutorial, Motivational, etc.)

### Personal Library
- **Cloud Sync**: Firestore-powered sync across devices
- **Offline Support**: SwiftData caching for instant access
- **Spotlight Search**: Find tips directly from iOS Home Screen

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | SwiftUI (iOS 17+) |
| AI SDK | Vertex AI in Firebase (Gemini 3 Flash) |
| Database | Cloud Firestore |
| Offline Cache | SwiftData |
| Auth | Sign in with Apple |
| Search | Core Spotlight |

## Project Structure

```
YTMate/
├── App/
│   ├── YTMateApp.swift          # App entry point
│   └── ContentView.swift         # Root view
├── Models/
│   ├── VideoSummary.swift        # Main data model
│   ├── ActionItem.swift          # Action item model
│   ├── VibeCategory.swift        # Content categories
│   └── GeminiResponse.swift      # API response schema
├── Views/
│   ├── LibraryView.swift         # Main library
│   ├── SummaryCardView.swift     # Summary preview card
│   ├── SummaryDetailView.swift   # Full summary view
│   ├── SummarySheetView.swift    # Processing sheet
│   ├── ActionItemRow.swift       # Action item display
│   ├── AuthView.swift            # Sign in screen
│   ├── SettingsView.swift        # App settings
│   ├── LoadingView.swift         # Loading animations
│   └── ClipboardToastView.swift  # URL detection toast
├── ViewModels/
│   ├── LibraryViewModel.swift    # Library logic
│   ├── SummaryViewModel.swift    # Summary generation
│   └── AuthViewModel.swift       # Authentication
├── Services/
│   ├── GeminiService.swift       # Vertex AI integration
│   ├── FirestoreService.swift    # Cloud sync
│   ├── AuthService.swift         # Sign in with Apple
│   ├── ClipboardService.swift    # URL detection
│   ├── SpotlightService.swift    # Search indexing
│   └── YouTubeURLParser.swift    # URL validation
├── Extensions/
│   ├── Date+Extensions.swift
│   ├── String+Extensions.swift
│   └── View+Extensions.swift
└── Resources/
    ├── Info.plist
    ├── YTMate.entitlements
    ├── GoogleService-Info.plist
    └── Assets.xcassets/

YTMateShareExtension/
├── ShareViewController.swift     # Extension entry point
├── ShareExtensionView.swift      # SwiftUI interface
└── Info.plist
```

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Firebase project with:
  - Vertex AI enabled
  - Firestore database
  - Authentication (Apple Sign-In)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Zeerakz/YT-Mate.git
   cd YT-Mate
   ```

2. Open `YTMate.xcodeproj` in Xcode

3. Configure Firebase:
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Vertex AI, Firestore, and Authentication
   - Download `GoogleService-Info.plist` and replace the placeholder

4. Update bundle identifiers:
   - Main app: `com.ytmate.app`
   - Share Extension: `com.ytmate.app.share`
   - App Group: `group.com.ytmate.app`

5. Enable capabilities in Xcode:
   - Sign in with Apple
   - App Groups
   - Associated Domains
   - Push Notifications

6. Build and run!

## User Flow

1. **Share**: User shares a YouTube link via iOS Share Sheet
2. **Analyze**: Half-height modal slides up, brain icon pulses
3. **Display**: Summary populates in 3-5 seconds
4. **Save**: Swipe down to auto-save, or tap "Edit" to add notes

## Prompt Engineering

The AI is configured with a system prompt optimized for actionable output:

```
You are an expert learning assistant. Your goal is to extract hard utility
from video content. Ignore fluff, intros, and sponsor reads.

For 'action_items', focus on instructions, not descriptions:
- BAD: "He talks about lighting"
- GOOD: "Place key light at 45-degree angle"
```

## Success Metrics

- **Latency**: < 5 seconds from share to render
- **Save Rate**: % of summaries kept vs. deleted
- **Share-Back**: Summaries exported to Notes/Slack

## Future Roadmap

- [ ] **Ask the Video**: Chat interface with 1M context window
- [ ] **Audio Mode**: Text-to-Speech for commuters
- [ ] **Widgets**: Home screen summary widgets
- [ ] **iPad Optimization**: Multi-column layout

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with Gemini 3 Flash.
