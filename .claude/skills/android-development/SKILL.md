---
name: android-development
description: "Scaffold, develop, and ship Android apps in Kotlin with Jetpack Compose. Covers architecture (MVVM/MVI), Jetpack libraries, dependency injection, testing, and Play Store submission. Trigger: /android-development"
trigger: /android-development
---

# /android-development

Full Android development skill. From project scaffold to Play Store — covers Jetpack Compose UI, MVVM/MVI architecture, Room, Retrofit, Hilt DI, testing, and release signing.

## Usage

```
/android-development                          # interactive setup wizard
/android-development --scaffold               # generate a new project structure
/android-development --architecture mvvm      # MVVM with StateFlow
/android-development --architecture mvi       # MVI with sealed state classes
/android-development --ui compose             # Jetpack Compose (default)
/android-development --ui xml                 # XML Views (legacy or preference)
/android-development --feature <name>         # scaffold a new feature module
/android-development --network                # add Retrofit + OkHttp + serialization
/android-development --db room                # add Room database
/android-development --di hilt                # add Hilt dependency injection
/android-development --auth firebase          # Firebase Authentication
/android-development --push fcm               # Firebase Cloud Messaging
/android-development --test                   # add unit + instrumentation test setup
/android-development --release                # release build, signing, Play Store checklist
/android-development --audit                  # audit existing project for issues
```

## What /android-development Delivers

Production-quality Android development requires more than "it works on my device":

1. **Correct architecture** — ViewModels that survive configuration changes, unidirectional data flow
2. **Lifecycle safety** — no memory leaks, no crashes from wrong coroutine scopes
3. **Modern tooling** — Compose, Hilt, Room, Retrofit wired together correctly from the start
4. **Testability** — code structured so unit tests don't require an emulator
5. **Release readiness** — signing, ProGuard/R8, Play Store requirements

---

## What You Must Do When Invoked

If no flags were given, run the setup wizard. If flags are present, go directly to the relevant step.

---

### Step 1 — Setup wizard (when no flags given)

Ask these questions in one message:

```
To scaffold your Android project, I need a few details:

1. App name and package name (e.g. "TaskMate", "com.example.taskmate")
2. Minimum API level: 21 (Android 5.0, 98% devices) / 24 (7.0, 95%) / 26 (8.0, 90%)
3. UI toolkit: Jetpack Compose (modern, recommended) / XML Views (legacy/preference)
4. Architecture: MVVM (simpler, more common) / MVI (strict unidirectional, better for complex state)
5. Backend: None / REST API (Retrofit) / Firebase / GraphQL
6. Local persistence: None / Room (SQLite) / DataStore (preferences)
7. Authentication: None / Firebase Auth / Custom JWT
```

Wait for answers before proceeding.

---

### Step 2 — Project scaffold

Generate the following structure (feature-first modular layout):

```
app/
├── src/
│   ├── main/
│   │   ├── java/com/example/myapp/
│   │   │   ├── MainActivity.kt
│   │   │   ├── MyApp.kt                    # Application class (Hilt entry point)
│   │   │   ├── core/
│   │   │   │   ├── di/                     # Hilt modules
│   │   │   │   ├── network/                # Retrofit client, interceptors
│   │   │   │   ├── database/               # Room database, DAOs
│   │   │   │   └── util/                   # extensions, helpers
│   │   │   ├── data/
│   │   │   │   ├── repository/             # Repository implementations
│   │   │   │   ├── local/                  # Room entities, DAOs
│   │   │   │   └── remote/                 # Retrofit services, DTOs
│   │   │   ├── domain/
│   │   │   │   ├── model/                  # domain models (not tied to DB or API)
│   │   │   │   ├── repository/             # repository interfaces
│   │   │   │   └── usecase/                # use cases / interactors
│   │   │   └── ui/
│   │   │       ├── theme/                  # MaterialTheme, colors, typography
│   │   │       ├── navigation/             # NavHost, routes
│   │   │       └── feature/                # one folder per screen/feature
│   │   │           └── home/
│   │   │               ├── HomeScreen.kt
│   │   │               ├── HomeViewModel.kt
│   │   │               └── HomeUiState.kt
│   │   ├── AndroidManifest.xml
│   │   └── res/
│   ├── test/                               # unit tests
│   └── androidTest/                        # instrumentation tests
├── build.gradle.kts
└── proguard-rules.pro
```

Generate `build.gradle.kts` (app level) with all dependencies version-catalogued:

```kotlin
// build.gradle.kts (app)
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.example.myapp"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.myapp"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}
```

---

### Step 3 — MVVM Architecture

Generate the full pattern for a feature. Use `Home` as the example:

#### ViewModel

```kotlin
// HomeViewModel.kt
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getItemsUseCase: GetItemsUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadItems()
    }

    private fun loadItems() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            getItemsUseCase()
                .onSuccess { items -> _uiState.update { it.copy(items = items, isLoading = false) } }
                .onFailure { error -> _uiState.update { it.copy(error = error.message, isLoading = false) } }
        }
    }

    fun onItemClicked(id: String) {
        // handle user events here, never in the composable
    }
}
```

#### UI State

```kotlin
// HomeUiState.kt
data class HomeUiState(
    val items: List<Item> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)
```

#### Screen (Jetpack Compose)

```kotlin
// HomeScreen.kt
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    HomeContent(
        uiState = uiState,
        onItemClicked = { id ->
            viewModel.onItemClicked(id)
            onNavigateToDetail(id)
        },
    )
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onItemClicked: (String) -> Unit,
) {
    when {
        uiState.isLoading -> CircularProgressIndicator()
        uiState.error != null -> ErrorMessage(uiState.error)
        else -> ItemList(uiState.items, onItemClicked)
    }
}
```

**Rules enforced:**
- `collectAsStateWithLifecycle()` (not `collectAsState()`) — stops collection when app is backgrounded
- No business logic in composables
- Composables receive state and callbacks only (no ViewModel reference in inner composables)
- `hiltViewModel()` called only in the screen-level composable, not in child composables

---

### Step 4 — MVI Architecture (when --architecture mvi)

For complex screens with many user events:

```kotlin
// HomeContract.kt — all state, events, effects in one file
sealed interface HomeEvent {
    data class ItemClicked(val id: String) : HomeEvent
    object RefreshRequested : HomeEvent
    data class SearchQueryChanged(val query: String) : HomeEvent
}

data class HomeState(
    val items: List<Item> = emptyList(),
    val isLoading: Boolean = false,
    val searchQuery: String = "",
    val error: String? = null,
)

sealed interface HomeEffect {
    data class NavigateToDetail(val id: String) : HomeEffect
    data class ShowSnackbar(val message: String) : HomeEffect
}
```

```kotlin
// HomeViewModel.kt (MVI)
@HiltViewModel
class HomeViewModel @Inject constructor(...) : ViewModel() {
    private val _state = MutableStateFlow(HomeState())
    val state: StateFlow<HomeState> = _state.asStateFlow()

    private val _effects = Channel<HomeEffect>(Channel.BUFFERED)
    val effects: Flow<HomeEffect> = _effects.receiveAsFlow()

    fun onEvent(event: HomeEvent) {
        when (event) {
            is HomeEvent.ItemClicked -> viewModelScope.launch {
                _effects.send(HomeEffect.NavigateToDetail(event.id))
            }
            is HomeEvent.RefreshRequested -> loadItems()
            is HomeEvent.SearchQueryChanged -> _state.update { it.copy(searchQuery = event.query) }
        }
    }
}
```

---

### Step 5 — Network layer (Retrofit + OkHttp)

```kotlin
// core/network/ApiClient.kt
@Singleton
class ApiClient @Inject constructor() {
    val okHttpClient: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BODY
                    else HttpLoggingInterceptor.Level.NONE
        })
        .addInterceptor { chain ->
            chain.proceed(
                chain.request().newBuilder()
                    .header("Authorization", "Bearer ${BuildConfig.API_KEY}")
                    .build()
            )
        }
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
        .build()
}
```

**Repository pattern:**
```kotlin
// Repository wraps network calls in Result<T>
class ItemRepositoryImpl @Inject constructor(
    private val apiService: ItemApiService,
    private val itemDao: ItemDao,
) : ItemRepository {

    override suspend fun getItems(): Result<List<Item>> = runCatching {
        val remote = apiService.getItems()
        itemDao.insertAll(remote.map { it.toEntity() })
        remote.map { it.toDomain() }
    }.recoverCatching {
        // Offline fallback
        itemDao.getAll().map { it.toDomain() }
    }
}
```

---

### Step 6 — Room database

```kotlin
// data/local/AppDatabase.kt
@Database(
    entities = [ItemEntity::class],
    version = 1,
    exportSchema = true,  // always true — needed for migration testing
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun itemDao(): ItemDao
}

// core/di/DatabaseModule.kt
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
            .addMigrations(MIGRATION_1_2)  // always add migrations, never fallbackToDestructiveMigration in prod
            .build()
}
```

---

### Step 7 — Hilt dependency injection

```kotlin
// MyApp.kt
@HiltAndroidApp
class MyApp : Application()

// MainActivity.kt
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MyAppTheme { AppNavHost() } }
    }
}
```

Key rules:
- `@HiltAndroidApp` on `Application` class
- `@AndroidEntryPoint` on every Activity, Fragment, Service that uses Hilt
- `@HiltViewModel` on every ViewModel
- Use `@Singleton` for network clients and databases
- Never use `@Singleton` for UI-related dependencies

---

### Step 8 — Navigation

```kotlin
// ui/navigation/AppNavHost.kt
@Composable
fun AppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(onNavigateToDetail = { id -> navController.navigate("detail/$id") })
        }
        composable(
            route = "detail/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { backStackEntry ->
            DetailScreen(
                id = backStackEntry.arguments?.getString("id") ?: return@composable,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
```

---

### Step 9 — Testing setup

**Unit test (ViewModel):**
```kotlin
// test/HomeViewModelTest.kt
@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
    @get:Rule val mainDispatcherRule = MainDispatcherRule()

    private val fakeRepository = FakeItemRepository()
    private lateinit var viewModel: HomeViewModel

    @Before
    fun setup() { viewModel = HomeViewModel(GetItemsUseCase(fakeRepository)) }

    @Test
    fun `loads items on init`() = runTest {
        val items = listOf(Item("1", "Task One"))
        fakeRepository.setItems(items)

        viewModel.uiState.test {
            val state = awaitItem()
            assertThat(state.items).isEqualTo(items)
            assertThat(state.isLoading).isFalse()
        }
    }
}
```

**Compose UI test:**
```kotlin
// androidTest/HomeScreenTest.kt
@HiltAndroidTest
class HomeScreenTest {
    @get:Rule val hiltRule = HiltAndroidRule(this)
    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun displaysItemList() {
        composeRule.onNodeWithText("Task One").assertIsDisplayed()
    }
}
```

---

### Step 10 — Release checklist (--release)

```
Release readiness checklist:
  [ ] versionCode incremented in build.gradle.kts
  [ ] versionName updated (semantic versioning: MAJOR.MINOR.PATCH)
  [ ] Keystore created and stored securely (NOT in git)
  [ ] Signing config added to build.gradle.kts (read from local.properties or env vars)
  [ ] isMinifyEnabled = true in release build type
  [ ] isShrinkResources = true in release build type
  [ ] BuildConfig.DEBUG gates removed from release API calls
  [ ] All logging removed or gated (Timber.plant() only in debug)
  [ ] Network security config set (cleartext disabled in production)
  [ ] Permissions declared in AndroidManifest.xml match actual usage
  [ ] App tested on physical device (not just emulator)
  [ ] App tested on minimum supported API level (minSdk)
  [ ] Crash reporting configured (Firebase Crashlytics recommended)
  [ ] Play Store: screenshots, description, content rating complete
  [ ] Play Store: target API level meets current requirement (check Google policy)
```

**Signing config (never hardcode credentials):**
```kotlin
// In build.gradle.kts
signingConfigs {
    create("release") {
        storeFile = file(System.getenv("KEYSTORE_PATH") ?: properties["keystore.path"].toString())
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: properties["keystore.password"].toString()
        keyAlias = System.getenv("KEY_ALIAS") ?: properties["key.alias"].toString()
        keyPassword = System.getenv("KEY_PASSWORD") ?: properties["key.password"].toString()
    }
}
```

---

### For --audit (existing project)

Read existing code and check:

- `viewModelScope.launch` called from UI (not ViewModel) → lifecycle leak risk
- `collectAsState()` used instead of `collectAsStateWithLifecycle()` → background wasted work
- `LiveData` used in new code → recommend migration to StateFlow
- Database access on main thread (no `withContext(Dispatchers.IO)`) → ANR risk
- `fallbackToDestructiveMigration()` in production database → data loss risk
- Hardcoded API keys or secrets in source files → CRITICAL security issue
- `@Singleton` on Activity/Fragment/ViewModel scoped dependencies → memory leak
- No ProGuard/R8 in release build → APK size and reverse-engineering risk
- `Dispatchers.Main` used in repository/data layer → performance issue

---

## Honesty Rules

- Never use `GlobalScope` — always use `viewModelScope` or `lifecycleScope`.
- Never access the database or network on the main thread.
- Never store secrets (API keys, tokens) in `BuildConfig` fields that will end up in release APKs without obfuscation.
- Never use `fallbackToDestructiveMigration()` in a production app with user data.
- Always flag when a pattern will cause memory leaks or ANRs.
- Minimum SDK selection is a business decision — present the trade-off (reach vs. feature access), don't decide for the user.
