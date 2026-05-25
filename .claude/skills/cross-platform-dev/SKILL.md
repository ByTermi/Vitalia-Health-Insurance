---
name: cross-platform-dev
description: "Scaffold and develop cross-platform apps with React Native, Flutter, or Kotlin Multiplatform. Covers shared business logic, platform-specific code, navigation, state management, native modules, and store submission. Trigger: /cross-platform-dev"
trigger: /cross-platform-dev
---

# /cross-platform-dev

Cross-platform app development skill. Covers React Native, Flutter, and Kotlin Multiplatform — from project scaffold to store submission — with correct patterns for shared logic, platform-specific divergence, navigation, state, and native module integration.

## Usage

```
/cross-platform-dev                           # interactive setup wizard
/cross-platform-dev --framework rn            # React Native (Expo or bare)
/cross-platform-dev --framework flutter       # Flutter (Dart)
/cross-platform-dev --framework kmp           # Kotlin Multiplatform (KMP)
/cross-platform-dev --expo                    # React Native with Expo (managed workflow)
/cross-platform-dev --bare                    # React Native bare workflow (full native access)
/cross-platform-dev --feature <name>          # scaffold a new feature (shared + platform code)
/cross-platform-dev --navigation              # navigation setup (stack, tab, drawer)
/cross-platform-dev --state redux             # Redux Toolkit state management (RN)
/cross-platform-dev --state zustand           # Zustand state management (RN)
/cross-platform-dev --state bloc              # BLoC pattern (Flutter)
/cross-platform-dev --state riverpod          # Riverpod (Flutter)
/cross-platform-dev --native-module           # scaffold a native module (platform-specific code)
/cross-platform-dev --network                 # HTTP client + API layer setup
/cross-platform-dev --auth                    # authentication flow (social + email/password)
/cross-platform-dev --push                    # push notifications (FCM + APNs)
/cross-platform-dev --test                    # testing setup (unit + e2e)
/cross-platform-dev --release                 # release build, signing, store submission checklist
/cross-platform-dev --audit                   # audit existing project for platform divergence and issues
```

## What /cross-platform-dev Delivers

The three promises of cross-platform (one codebase, two stores, native feel) break down without discipline:

1. **Correct platform abstraction** — know what to share (business logic, API calls, state) vs. what to split (UI affordances, permissions, file paths)
2. **Platform-specific code done right** — not hacky `Platform.OS === 'ios'` scattered everywhere, but proper abstraction boundaries
3. **Performance** — JS thread/Dart isolate patterns that don't block the UI thread
4. **Real native integration** — native modules that don't crash, don't leak, and bridge correctly

---

## What You Must Do When Invoked

If no flags were given, run the setup wizard. If flags are present, go directly to the relevant step.

---

### Step 1 — Setup wizard (when no flags given)

Ask these questions in one message:

```
To scaffold your cross-platform project, I need a few details:

1. Framework preference:
   - React Native (Expo) — fastest start, managed build, 90% of use cases
   - React Native (bare) — full native access, more setup
   - Flutter — best UI consistency, Dart, strong performance
   - Kotlin Multiplatform — share only business logic, fully native UI per platform

2. Target platforms: iOS + Android / iOS only / Android only / + Web / + Desktop

3. App type: Consumer app / Internal tool / E-commerce / Content / Game

4. Backend: None / REST API / Firebase / GraphQL / tRPC

5. Authentication: None / Email+password / Social (Google/Apple/Facebook) / Both

6. State complexity: Simple (local state only) / Moderate (shared app state) / Complex (offline sync, real-time)
```

Wait for answers before proceeding.

---

### Step 2 — Framework-specific scaffold

#### React Native (Expo)

```
my-app/
├── app/                          # Expo Router (file-based routing)
│   ├── (tabs)/
│   │   ├── index.tsx             # Home tab
│   │   ├── explore.tsx           # Explore tab
│   │   └── _layout.tsx           # Tab navigator config
│   ├── (auth)/
│   │   ├── login.tsx
│   │   └── _layout.tsx
│   └── _layout.tsx               # Root layout (providers, global setup)
├── src/
│   ├── components/               # shared UI components
│   ├── hooks/                    # custom hooks
│   ├── store/                    # Zustand / Redux store
│   ├── api/                      # API client and endpoints
│   ├── utils/                    # pure utilities (no RN imports)
│   └── types/                    # TypeScript types
├── assets/
├── app.json
└── package.json
```

**`app.json` essentials:**
```json
{
  "expo": {
    "name": "MyApp",
    "slug": "my-app",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "splash": { "image": "./assets/splash.png", "resizeMode": "contain" },
    "ios": {
      "bundleIdentifier": "com.example.myapp",
      "supportsTablet": true,
      "infoPlist": {
        "NSCameraUsageDescription": "$(PRODUCT_NAME) needs camera access to..."
      }
    },
    "android": {
      "package": "com.example.myapp",
      "adaptiveIcon": { "foregroundImage": "./assets/adaptive-icon.png" },
      "permissions": []
    },
    "plugins": ["expo-router"],
    "scheme": "myapp"
  }
}
```

---

#### Flutter

```
lib/
├── main.dart                     # entry point, ProviderScope or MaterialApp
├── app/
│   ├── app.dart                  # MaterialApp / CupertinoApp setup
│   ├── router/                   # GoRouter config
│   └── theme/                    # ThemeData, colors, text styles
├── features/
│   └── home/
│       ├── data/                 # repositories, data sources
│       ├── domain/               # models, use cases
│       └── presentation/         # screens, widgets, providers/blocs
├── core/
│   ├── network/                  # Dio client, interceptors
│   ├── storage/                  # local storage (Hive / Isar / shared_preferences)
│   └── utils/                    # extensions, helpers
└── l10n/                         # localization ARB files
```

**`pubspec.yaml` essentials:**
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter: { sdk: flutter }
  go_router: ^13.0.0
  flutter_riverpod: ^2.5.0     # or flutter_bloc
  dio: ^5.4.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  hive_flutter: ^1.1.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  flutter_test: { sdk: flutter }
  mocktail: ^1.0.0
```

---

#### Kotlin Multiplatform (KMP)

```
shared/
├── src/
│   ├── commonMain/kotlin/com/example/
│   │   ├── data/                 # Repository implementations, network, storage
│   │   ├── domain/               # Models, use cases, repository interfaces
│   │   └── presentation/         # ViewModels (shared, using KMM ViewModel)
│   ├── iosMain/kotlin/           # iOS-specific implementations (Keychain, NSDate, etc.)
│   └── androidMain/kotlin/       # Android-specific implementations
androidApp/
iosApp/
```

**What to put in `commonMain` (shared):**
- All business logic
- Repository interfaces and implementations (Ktor for HTTP, SQLDelight for DB)
- ViewModels (using `moko-mvvm` or KMP ViewModel)
- Domain models

**What stays platform-specific:**
- UI (fully native — Compose on Android, SwiftUI on iOS)
- Platform services (camera, notifications, biometrics)
- Deep links, URI schemes

---

### Step 3 — Platform-specific code abstraction

**Anti-pattern (scattered inline checks):**
```tsx
// BAD — platform checks scattered everywhere
const inputStyle = Platform.OS === 'ios'
  ? { paddingTop: 10 }
  : { paddingTop: 6 }
```

**Correct pattern (platform file extension):**
```
components/
  DatePicker.ios.tsx      # iOS implementation (native DatePicker)
  DatePicker.android.tsx  # Android implementation (native DatePicker)
  DatePicker.tsx          # Fallback / shared interface type
```

```tsx
// DatePicker.ios.tsx
export function DatePicker({ value, onChange }: DatePickerProps) {
  return <RNDateTimePicker mode="date" value={value} onChange={onChange} />
}

// DatePicker.android.tsx
export function DatePicker({ value, onChange }: DatePickerProps) {
  return <DateTimePickerAndroid /* Android-specific API */ />
}
```

Metro bundler (React Native) picks the right file automatically. No runtime `Platform.OS` check needed.

**Flutter equivalent (Platform conditional):**
```dart
// Use Theme.of(context).platform for UI decisions
// Use dart:io Platform for service decisions
import 'dart:io';

Widget buildPlatformButton() {
  return Platform.isIOS
      ? CupertinoButton(child: const Text('Submit'), onPressed: onSubmit)
      : ElevatedButton(child: const Text('Submit'), onPressed: onSubmit);
}
```

---

### Step 4 — Navigation

#### React Native (Expo Router)

File-based routing — routes are derived from the file system:

```tsx
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router'
import { TabBarIcon } from '@/components/TabBarIcon'

export default function TabLayout() {
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: '#007AFF' }}>
      <Tabs.Screen name="index" options={{ title: 'Home', tabBarIcon: ({ color }) => <TabBarIcon name="home" color={color} /> }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile', tabBarIcon: ({ color }) => <TabBarIcon name="person" color={color} /> }} />
    </Tabs>
  )
}
```

```tsx
// Programmatic navigation
import { router } from 'expo-router'
router.push('/detail/123')
router.replace('/(auth)/login')
router.back()
```

#### Flutter (GoRouter)

```dart
// app/router/router.dart
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated && !state.location.startsWith('/auth')) return '/auth/login';
    return null;
  },
  routes: [
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/detail/:id',
      builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/auth/login', builder: (context, state) => const LoginScreen()),
  ],
);
```

---

### Step 5 — State management

#### React Native — Zustand (recommended for most apps)

```ts
// store/useAppStore.ts
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

interface AppState {
  user: User | null
  items: Item[]
  setUser: (user: User | null) => void
  setItems: (items: Item[]) => void
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      user: null,
      items: [],
      setUser: (user) => set({ user }),
      setItems: (items) => set({ items }),
    }),
    { name: 'app-storage', storage: createJSONStorage(() => AsyncStorage) }
  )
)
```

#### Flutter — Riverpod (recommended)

```dart
// features/home/presentation/providers.dart
@riverpod
Future<List<Item>> items(ItemsRef ref) async {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.getItems();
}

// In widget:
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);
    return itemsAsync.when(
      data: (items) => ItemList(items: items),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => ErrorWidget(e.toString()),
    );
  }
}
```

---

### Step 6 — Native module scaffold

For React Native, when a native capability is needed that no Expo module covers:

```
modules/
  CameraScanner/
    ios/
      CameraScanner.h
      CameraScanner.m       # or .swift with bridging header
    android/
      src/main/java/com/example/
        CameraScanner.kt
        CameraScannerPackage.kt
    index.ts                # JavaScript interface
    CameraScanner.types.ts  # TypeScript types
```

```ts
// index.ts — JavaScript/TypeScript interface
import { NativeModules, Platform } from 'react-native'

const { CameraScanner } = NativeModules

export const scan = (): Promise<string> => {
  if (!CameraScanner) throw new Error('CameraScanner module not available')
  return CameraScanner.scan()
}
```

Always check if an existing Expo module or community library covers the use case before writing a native module.

---

### Step 7 — Performance patterns

#### React Native

**Avoid re-renders:**
```tsx
// Memoize expensive components
const ItemRow = React.memo(({ item, onPress }: ItemRowProps) => {
  return <Pressable onPress={() => onPress(item.id)}><Text>{item.name}</Text></Pressable>
})

// Use useCallback for callbacks passed to memoized children
const handlePress = useCallback((id: string) => {
  router.push(`/detail/${id}`)
}, [])
```

**FlatList optimization:**
```tsx
<FlatList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <ItemRow item={item} onPress={handlePress} />}
  getItemLayout={(_, index) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * index, index })}
  maxToRenderPerBatch={10}
  windowSize={5}
  removeClippedSubviews={true}
/>
```

**Move heavy work off the JS thread:**
```ts
// Use react-native-worklets-core or Reanimated for animations
// Use expo-task-manager for background tasks
// Use react-native-workers for CPU-heavy computation
```

#### Flutter

```dart
// Use const constructors wherever possible — prevents rebuilds
const Text('Static label')

// Use ListView.builder for large lists — lazy rendering
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(item: items[index]),
)

// Isolates for heavy computation
final result = await compute(heavyComputation, inputData);
```

---

### Step 8 — Testing

#### React Native

```ts
// Unit test (Jest + Testing Library)
import { render, fireEvent } from '@testing-library/react-native'

it('calls onPress when button tapped', () => {
  const onPress = jest.fn()
  const { getByText } = render(<MyButton title="Submit" onPress={onPress} />)
  fireEvent.press(getByText('Submit'))
  expect(onPress).toHaveBeenCalledTimes(1)
})

// E2E (Maestro — recommended for RN)
// .maestro/flows/login.yaml
```

#### Flutter

```dart
// Widget test
testWidgets('shows items when loaded', (WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [itemsProvider.overrideWith((_) async => [Item(id: '1', name: 'Test')])],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Test'), findsOneWidget);
});
```

---

### Step 9 — Release checklist (--release)

```
iOS:
  [ ] Bundle ID matches App Store Connect
  [ ] Signing certificates and provisioning profiles set up in Xcode
  [ ] Icon: 1024×1024px, no alpha channel
  [ ] Splash screen configured
  [ ] NSUsageDescription strings added for every permission in Info.plist
  [ ] App tested on physical device (simulator is not enough for performance)
  [ ] Privacy manifest (PrivacyInfo.xcprivacy) included if using APIs that require it

Android:
  [ ] Keystore file created and backed up securely (NOT in git)
  [ ] signingConfigs configured in build.gradle
  [ ] App Bundle (.aab) generated (not APK) for Play Store
  [ ] Target API level meets Google's current requirement
  [ ] Adaptive icon provided (foreground + background layers)
  [ ] All permissions declared in AndroidManifest.xml justified

Both:
  [ ] Version number and build number incremented
  [ ] Production API endpoint configured (not dev/staging)
  [ ] Analytics and crash reporting enabled (Firebase Crashlytics)
  [ ] Deep links / universal links tested
  [ ] Tested on low-end device (not just flagship)
  [ ] App tested with slow network (airplane mode + switch on)
  [ ] Screenshots and store listing complete
```

---

### For --audit (existing project)

Read existing code and check:

**React Native:**
- `console.log` statements left in production code → performance hit
- Missing `keyExtractor` on FlatList → React reconciliation errors
- Using `useEffect` with missing dependencies → stale closure bugs
- State mutations instead of `setState` → silent bugs
- `Platform.OS` checks in component bodies instead of `.ios.tsx` / `.android.tsx` files → maintainability issue
- Missing `memo` / `useCallback` on expensive renders → re-render performance

**Flutter:**
- Rebuilding entire widget trees on state change (should use selective `Consumer` or `watch`)
- `setState` called in `StatelessWidget` context → crash
- `async` without error handling → unhandled Future rejections
- Missing `const` constructors on static widgets → unnecessary rebuilds
- `Navigator.push` without named routes → deep link support broken

**Both:**
- API keys or secrets committed to source → CRITICAL
- No error boundaries / error handling screens
- Production analytics sending data to dev endpoint
- No handling of network errors or offline state

---

## Honesty Rules

- Cross-platform ≠ identical UX on every platform. iOS and Android users have different expectations. Always flag when a design choice will feel wrong on one platform.
- Expo managed workflow has limits. If the user's use case requires a native module not covered by Expo, tell them upfront — don't let them hit it mid-project.
- Flutter's "pixel-perfect on both platforms" comes at the cost of not using native components. This is usually fine; flag the exceptions (date pickers, form inputs, keyboards).
- KMP shares logic, not UI. Never suggest KMP as a way to "write one UI for both platforms" — that's React Native or Flutter's job.
- Performance on low-end Android devices is the real test. Never claim performance is good without testing on a budget device.
