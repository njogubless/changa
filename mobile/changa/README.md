# changa

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.
# Changa Mobile App 📱

> *You had the idea. You set up the backend. Now here's the app that puts it in people's hands — on the phone in their pocket, on the matatu, in the chama meeting.*

This is the Flutter mobile app for **Changa**, the group contribution platform built for Kenya. It talks to the FastAPI backend, handles M-Pesa and Airtel Money payments, and presents everything through a UI that feels premium and intentional — not like a template.

Android 7.0 through Android 14. No fuss.

---

## What's Inside

- **Flutter 3.41 + Dart 3.11** — latest stable, targeting Android API 24–34
- **Riverpod 2.x** — compile-safe, context-free state management
- **Clean Architecture** — presentation → domain → data, no shortcuts
- **Dio + JWT Interceptor** — tokens attach automatically, refresh silently on expiry
- **go_router** — declarative navigation with auth guards built in
- **flutter_secure_storage** — access and refresh tokens encrypted on-device
- **Custom design system** — `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` — every visual decision in one file
- **Sora + DM Sans** — a font pairing that looks sharp on every Android screen
- **M-Pesa & Airtel payment screens** — full STK Push flow with status polling
- **Onboarding + Splash** — animated logo, three-slide onboarding, first-run detection
- **Dark mode** — system-aware, works across the full app

---

## The User Journey

### Journey 1: First Launch → Pay → Dashboard

This is the experience you're building toward.

1. App opens → splash screen with animated Changa logo
2. First-time user → three-slide onboarding (swipeable, skippable)
3. User taps "Get started" → `RegisterScreen`
4. They fill in name, email, M-Pesa number (`254XXXXXXXXX`), password
5. On success → automatically logged in → `ProjectsListScreen` (Home)
6. They browse, tap a project → `ProjectDetailScreen` with live funding progress
7. They tap "Contribute" → `PaymentScreen` with quick-amount chips
8. They select KES 500, pick M-Pesa, confirm phone → "Pay with M-Pesa"
9. App calls the backend → backend triggers STK Push → phone buzzes
10. User enters M-Pesa PIN → `PaymentStatusScreen` starts polling
11. Safaricom confirms → screen transitions to success with receipt number

### Journey 2: Returning User, Token Expired

Tokens expire after 30 minutes. The user never notices.

1. User opens the app after a few hours
2. App tries `GET /projects` → backend returns `401 Unauthorized`
3. The `AuthInterceptor` in `api_client.dart` catches this silently
4. Interceptor calls `POST /auth/refresh` with the stored refresh token
5. Gets a new access token → saves it → retries the original request
6. `ProjectsListScreen` loads as if nothing happened

### Journey 3: App Opened Cold, Already Logged In

1. App starts → `SplashScreen` shows for ~2.4 seconds
2. In the background, `AuthNotifier` checks for a stored access token
3. If token exists → validates with `GET /auth/me`
4. If valid → router redirects to `/home` (skips login entirely)
5. If invalid → router redirects to `/login`

---

## Project Structure

```
mobile/lib/
│
├── main.dart                              ← ProviderScope, MaterialApp.router, theme, locale
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart            ← App name, asset paths, storage keys, poll settings
│   │   └── api_constants.dart           ← Base URL + every endpoint path in one place
│   ├── theme/
│   │   └── app_theme.dart               ← AppColors, AppTextStyles, AppSpacing, AppRadius,
│   │                                       AppShadows, full ThemeData (light + dark)
│   ├── network/
│   │   └── api_client.dart              ← Dio setup, AuthInterceptor, auto token refresh,
│   │                                       dioExceptionToFailure() helper
│   ├── errors/
│   │   └── failures.dart                ← Typed failures: NetworkFailure, AuthFailure,
│   │                                       PaymentFailure, ValidationFailure, etc.
│   ├── router/
│   │   ├── app_router.dart              ← All routes, auth redirect guard, error page
│   │   └── shell_screen.dart           ← Bottom nav bar (Home / Projects / Profile)
│   └── utils/
│       └── currency_formatter.dart     ← format() → "KES 1,500.00", formatCompact() → "KES 1.5K"
│
└── features/
    ├── splash/
    │   └── presentation/screens/
    │       └── splash_screen.dart       ← Animated logo, geometric bg, loading dots, auto-nav
    │
    ├── onboarding/
    │   └── presentation/screens/
    │       └── onboarding_screen.dart  ← 3-page swipeable intro, skip/next/get-started
    │
    ├── auth/
    │   ├── presentation/
    │   │   ├── providers/
    │   │   │   └── auth_provider.dart  ← AuthState (sealed), AuthNotifier, login/register/logout
    │   │   ├── screens/
    │   │   │   ├── login_screen.dart
    │   │   │   └── register_screen.dart
    │   │   └── widgets/
    │   │       ├── auth_text_field.dart ← Reusable labeled input with prefix/suffix icons
    │   │       └── auth_header.dart    ← Logo + title + subtitle component
    │
    ├── projects/
    │   ├── presentation/
    │   │   ├── providers/
    │   │   │   └── projects_provider.dart ← ProjectModel, paginated list, single project,
    │   │   │                                  create project, infinite scroll
    │   │   └── screens/
    │   │       ├── projects_list_screen.dart  ← SliverAppBar greeting, search, project cards
    │   │       ├── project_detail_screen.dart ← Progress bar, stats, description, contribute CTA
    │   │       └── create_project_screen.dart ← Title, description, target, visibility, anonymous
    │
    ├── payments/
    │   └── presentation/screens/
    │       ├── payment_screen.dart          ← Quick amounts, M-Pesa/Airtel selector, phone input
    │       └── payment_status_screen.dart  ← 3-second polling, animated status, receipt display
    │
    └── profile/
        └── presentation/screens/
            └── profile_screen.dart         ← Avatar, contribution stats, project history, logout
```

---

## Getting Started

### Prerequisites

- Flutter 3.19+ (`flutter --version`)
- Android SDK with API level 24–34
- The Changa backend running (see `backend/README.md`)
- Sora and DM Sans font files (free from [fonts.google.com](https://fonts.google.com))

### Step 1: Create the Flutter project

```bash
cd changa/
flutter create mobile --org ke.co.changa --platforms android
cd mobile
```

### Step 2: Copy source files

Replace the generated `lib/` folder with the one from this project.

Also copy:
- `pubspec.yaml` → replaces the generated one
- `flutter_native_splash.yaml`
- `analysis_options.yaml`

### Step 3: Download fonts

Go to [fonts.google.com](https://fonts.google.com) and download:
- **Sora** (all weights: Light, Regular, SemiBold, Bold, ExtraBold)
- **DM Sans** (Regular, Medium, Bold)

Place them in `assets/fonts/`. File names must match `pubspec.yaml` exactly.

### Step 4: Create asset folders

```bash
mkdir -p assets/fonts assets/images assets/animations assets/icons
```

Add your logo to `assets/images/logo.png` — a 288×288 transparent PNG works best.

### Step 5: Update the API URL

Open `lib/core/constants/api_constants.dart` and set your backend URL:

```dart
// Android emulator (your laptop = 10.0.2.2 from inside the emulator)
static const String baseUrl = 'http://10.0.2.2:8000';

// Physical device on the same Wi-Fi network
static const String baseUrl = 'http://192.168.X.X:8000';

// Production
static const String baseUrl = 'https://api.changa.co.ke';
```

### Step 6: Update Android SDK config

In `android/app/build.gradle`:

```gradle
minSdkVersion 24      // Android 7.0 — widest compatible range
targetSdkVersion 34   // Android 14 — latest
compileSdkVersion 34
multiDexEnabled true  // Required for flutter_secure_storage
```

In `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### Step 7: Install and run

```bash
flutter pub get
dart run flutter_native_splash:create
flutter run
```

---

## The Design System

Everything visual lives in `lib/core/theme/app_theme.dart`. Change it once, change it everywhere.

### Colors

```dart
AppColors.forest      // #1B4332 — primary brand (M-Pesa green family)
AppColors.sage        // #52B788 — accent, progress bars
AppColors.mint        // #95D5B2 — success, light fills
AppColors.terra       // #C75B39 — CTA buttons, errors, Airtel flows
AppColors.gold        // #E8A020 — highlights, badges, completion
AppColors.cream       // #FAF3E0 — light mode background
AppColors.earth       // #2C1A0E — dark mode background
AppColors.sand        // #E8D5A3 — borders, dividers
AppColors.mpesaGreen  // #00A550 — official M-Pesa brand color
AppColors.airtelRed   // #E40520 — official Airtel brand color
```

### Typography

```dart
AppTextStyles.display1    // 48px Sora ExtraBold — hero amounts
AppTextStyles.h1          // 28px Sora Bold — screen titles
AppTextStyles.h3          // 18px Sora Bold — section headers
AppTextStyles.bodyLarge   // 16px DM Sans — main body text
AppTextStyles.bodySmall   // 12px DM Sans — captions, hints
AppTextStyles.button      // 14px Sora SemiBold — all button labels
AppTextStyles.amount      // 32px Sora ExtraBold — KES amounts
AppTextStyles.tab         // 12px Sora SemiBold — nav labels
```

### Spacing & Radius

```dart
AppSpacing.lg       // 16px — standard component padding
AppSpacing.xxl      // 24px — section gaps
AppSpacing.pagePadding  // EdgeInsets.symmetric(horizontal: 20)

AppRadius.mdAll     // BorderRadius.all(Radius.circular(12))
AppRadius.lgAll     // BorderRadius.all(Radius.circular(16))
AppRadius.pillAll   // BorderRadius.all(Radius.circular(999))
```

---

## State Management with Riverpod

Every feature follows the same Riverpod pattern. No exceptions.

```
User action (button tap)
        ↓
Screen calls ref.read(provider.notifier).method()
        ↓
Notifier updates state (loading → success/error)
        ↓
Screen rebuilds via ref.watch(provider)
        ↓
UI shows new state
```

Key providers:

```dart
// Auth — who is logged in
authNotifierProvider   // StateNotifier<AuthState> — login, register, logout
currentUserProvider    // Provider<UserEntity?> — the current user or null

// Projects — the data
projectsProvider       // StateNotifier<ProjectsState> — paginated list + refresh
projectDetailProvider  // FutureProvider.family<ProjectModel, int> — single project
createProjectProvider  // Provider — function to call for creating projects

// Routing — reacts to auth state
routerProvider         // Provider<GoRouter> — rebuilds when auth changes
```

---

## Navigation

All routes are defined in `lib/core/router/app_router.dart`:

```
/                  → SplashScreen (decides where to go next)
/onboarding        → OnboardingScreen (first-time only)
/login             → LoginScreen
/register          → RegisterScreen
/home              → ProjectsListScreen  ─┐
/projects          → ProjectsListScreen   │ Protected by auth guard
/projects/:id      → ProjectDetailScreen  │ (redirects to /login if not authenticated)
/projects/create   → CreateProjectScreen  │
/profile           → ProfileScreen       ─┘
/payment           → PaymentScreen (full screen, no bottom nav)
/payment/status    → PaymentStatusScreen
```

The auth guard in `go_router` runs on every navigation:

```dart
redirect: (context, state) {
  if (!isLoggedIn && !isOnAuthRoute) return '/login';
  if (isLoggedIn && isOnAuthRoute) return '/home';
  return null; // no redirect
}
```

---

## Android Compatibility

The app is tested and designed to run on Android 7.0 through Android 14.

| Android Version | API Level | Target? |
|----------------|-----------|---------|
| 7.0 Nougat | 24 | Minimum |
| 8.0 Oreo | 26 | ✓ |
| 9.0 Pie | 28 | ✓ |
| 10 | 29 | ✓ |
| 11 | 30 | ✓ |
| 12 | 31 | ✓ |
| 13 | 33 | ✓ |
| 14 | 34 | Target |

This covers **95%+ of Android devices active in Kenya** as of 2026.

---

## The Honest Limitations

You deserve to know exactly what this is and isn't.

**No iOS support yet.** The `flutter create` command was run with `--platforms android`. Adding iOS takes a separate signing setup, but the Flutter code itself is fully cross-platform — just add `ios` to the platform list and configure signing.

**No offline mode.** The app requires an active internet connection. There's no local caching of project data or offline contribution queuing. For a market with variable connectivity, this is worth addressing — `drift` (SQLite ORM) is a solid choice for local data.

**No push notifications.** When a contribution to your project succeeds, the project owner doesn't get a push notification. Adding Firebase Cloud Messaging is a straightforward extension, but it's not wired up here.

**No image uploads.** User avatars and project cover images are URLs stored in the database, but there's no upload flow. You'd add `image_picker` and connect to cloud storage (Supabase Storage or Cloudinary) to enable this.

**No biometric login.** The `flutter_local_auth` package makes this easy to add, and `flutter_secure_storage` already handles the tokens securely. It's a good next step for UX.

**No deep links.** If a user shares a project link, the app doesn't open to that project. `go_router` supports deep linking well — it just needs to be configured with your domain.

**Text scale is clamped.** `main.dart` clamps text scaling to 0.8–1.2× for layout stability. This trades some accessibility for predictable layouts. You may want to loosen this.

---

## The Roadmap

Here's how you turn this into an app people recommend to their chama:

**Step 1 — Offline-first projects list.** Cache projects locally with `drift`. Show cached data immediately on launch, refresh in background. Enormous UX improvement for users on Safaricom's edge network.

**Step 2 — Push notifications.** Integrate Firebase Cloud Messaging. Notify project owners when contributions come in. Notify contributors when the project hits its goal. These notifications drive re-engagement.

**Step 3 — Project sharing.** Add a share button to `ProjectDetailScreen`. Generate a deep link (`changa://projects/42`) and a web fallback URL. Let members invite people from WhatsApp.

**Step 4 — Image support.** Add `image_picker` for profile avatars and project cover photos. Connect to Supabase Storage or Cloudinary. Projects with cover images convert better.

**Step 5 — Contribution receipts.** Generate a simple PDF receipt after a successful payment using `pdf` package. Users can share or save it. Builds trust.

**Step 6 — iOS build.** Run `flutter create --platforms ios .` in the project root. Configure signing in Xcode. The codebase is ready — it's just the platform config.

**Step 7 — Localization.** Add Swahili (`sw`) as a second language using `flutter_localizations`. Kenya is bilingual — a lot of users will appreciate this.

---

## Common Issues

**"Connection refused" on Android emulator**

The emulator can't reach `localhost` — use `10.0.2.2` instead:
```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

**"Cleartext HTTP traffic not permitted" on Android**

Add this to `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:usesCleartextTraffic="true" ...>
```
Only for development. Use HTTPS in production.

**Fonts not loading**

Font file names in `pubspec.yaml` must exactly match the `.ttf` files in `assets/fonts/`. Case sensitive.

**Splash screen not updating**

```bash
dart run flutter_native_splash:remove
dart run flutter_native_splash:create
```

**`MissingPluginException` for flutter_secure_storage**

Add to `android/app/build.gradle`:
```gradle
defaultConfig {
    multiDexEnabled true
}
```

---

## Running Tests

```bash
flutter test
```

The test structure mirrors the feature structure. Add tests in `test/features/<feature>/`.

---

## A Final Word

A lot of app developers build for Silicon Valley. You're building for Nairobi. For people whose daily transaction is a Safaricom STK Push, whose community organizing happens in WhatsApp groups, whose trust in a product is earned by it working the first time.

The architecture is clean. The payment flow is solid. The design respects the user.

What you do with it is up to you.

**Now go build something worth downloading.**
A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
a contribution project that incorporates both FastAPI and flutter and dart 
>>>>>>> cb56bdb9f6bfc604779782b4625168975a43b8aa
