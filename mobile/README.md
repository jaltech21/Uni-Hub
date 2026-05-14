# UniHub Mobile App

A React Native mobile application for UniHub - The All-in-One Student Virtual Assistant. Built with Expo, TypeScript, and NativeWind styling.

## 📱 Features

- **Authentication**: Secure login and registration
- **Dashboard**: Overview of classes, assignments, and notes
- **Notes**: Create, edit, and summarize notes with AI
- **Assignments**: View and submit assignments
- **Schedule**: Manage your academic calendar
- **Messages**: Real-time communication with classmates
- **Attendance**: Mark attendance digitally
- **Quizzes**: AI-generated quizzes from notes

## 🛠️ Tech Stack

- **Framework**: React Native with Expo
- **Language**: TypeScript
- **Styling**: NativeWind (Tailwind CSS for React Native)
- **Navigation**: React Navigation
- **State Management**: Context API
- **API Client**: Axios with interceptors
- **Authentication**: Token-based JWT
- **Storage**: react-native-keychain (secure) + AsyncStorage
- **Testing**: Jest + React Native Testing Library

## 📋 Prerequisites

- Node.js 16+ and npm/yarn
- Expo CLI: `npm install -g expo-cli`
- iOS: Xcode (macOS)
- Android: Android Studio
- For EAS builds: EAS CLI and Expo account

## 🚀 Getting Started

### 1. Install Dependencies

```bash
npm install
# or
yarn install
```

### 2. Set Up Environment Variables

```bash
cp .env.example .env.local
# Edit .env.local with your API URL and credentials
```

### 3. Start Development Server

```bash
npm start
# or
expo start
```

### 4. Run on Device/Emulator

**iOS:**
```bash
npm run ios
```

**Android:**
```bash
npm run android
```

**Web (for development):**
```bash
npm run web
```

## 📁 Project Structure

```
mobile/
├── app/
│   ├── screens/          # Screen components (auth, app)
│   ├── components/       # Reusable UI components
│   ├── services/         # API client, auth service
│   ├── context/          # Context providers (Auth)
│   ├── navigation/       # Navigation setup
│   ├── theme/           # Design tokens and theme
│   ├── types/           # TypeScript type definitions
│   ├── hooks/           # Custom React hooks
│   ├── utils/           # Helper functions
│   └── __tests__/       # Test files
├── docs/                 # Documentation
├── App.tsx              # Root component
├── app.json             # Expo configuration
├── package.json         # Dependencies
├── tsconfig.json        # TypeScript config
├── tailwind.config.js   # Tailwind configuration
└── babel.config.js      # Babel configuration
```

## 🎨 Design System

The app uses a professional design system with:

- **Colors**: Primary blue (#3b5bfd), secondary gray, accent red
- **Typography**: Consistent font sizes and weights
- **Spacing**: Modular spacing scale (4px, 8px, 16px, 24px, etc.)
- **Shadows**: Layered shadows for depth
- **Border Radius**: Rounded corners (4px, 8px, 12px, etc.)

See [Design Tokens](app/theme/index.ts) for details.

## 🧪 Testing

```bash
# Run tests
npm test

# Watch mode
npm run test:watch

# With coverage
npm test -- --coverage
```

## 📝 Code Quality

```bash
# Type checking
npm run type-check

# Linting
npm run lint

# Fix lint issues
npm run lint -- --fix
```

## 🔐 Authentication Flow

1. User enters credentials on login screen
2. API client sends request to `/auth/login` endpoint
3. Backend returns access token and refresh token
4. Tokens stored securely in react-native-keychain
5. All subsequent requests include Bearer token
6. On token expiry, automatic refresh via interceptor
7. Failed refresh triggers logout

## 📡 API Integration

All API requests go through a centralized client (`services/api.ts`) with:

- Automatic token injection
- Token refresh interceptor
- Error handling and validation
- File upload support
- Request/response logging

## 🚢 Deployment

### Build for App Stores

```bash
# Prebuild native code
npm run prebuild

# Build for EAS
npm run build

# Submit to stores
npm run submit
```

### Staging vs Production

Update API URL in `.env.local`:
- **Staging**: `http://staging-api.unihub.app/api/v1`
- **Production**: `https://api.unihub.app/api/v1`

## 📚 Documentation

- [Design System](docs/design/README.md) - UI/UX guidelines
- [API Documentation](docs/api/README.md) - Backend endpoints
- [Development Guide](docs/development/README.md) - Development workflow
- [Testing Strategy](docs/testing/README.md) - Testing best practices

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/mobile/<feature>`
2. Make changes and test locally
3. Submit a pull request to `feature/mobile-react-native`
4. Request design review for UI/UX changes
5. Ensure all tests pass before merging

## 🐛 Troubleshooting

**Issue**: Metro bundler not starting
```bash
npm start -- --reset-cache
```

**Issue**: Module not found errors
```bash
npm install
cd node_modules/@react-native-gesture-handler && npm run postinstall
```

**Issue**: Keychain errors (iOS)
- Ensure proper provisioning profile is set
- Check entitlements in Xcode

## 📦 Build Size

Target: < 50MB on App Store, < 60MB on Play Store

Monitor with:
```bash
npm run build -- --production
```

## 🎯 Next Steps

- [ ] Implement push notifications
- [ ] Add offline-first caching
- [ ] Implement real-time messaging with WebSockets
- [ ] Add camera/photo library integration
- [ ] Implement file uploads for assignments
- [ ] Add analytics tracking
- [ ] Performance optimization and code splitting

## 📄 License

UniHub Mobile © 2026. All rights reserved.

## 📧 Support

For issues or questions:
- GitHub Issues: [Report a bug]
- Email: support@unihub.app

---

**Last Updated**: May 14, 2026  
**Version**: 0.1.0 (Scaffold)
