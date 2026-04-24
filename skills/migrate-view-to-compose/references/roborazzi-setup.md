# Roborazzi module setup

Loaded when Pre-flight step 4 reports `NEEDS SETUP`. One-time per module — idempotent.

## Build configuration

Add the convention plugin to the module — it handles plugin application and test dependencies:

```kotlin
// <module>/build.gradle.kts
plugins {
    // existing plugins...
    alias(libs.plugins.abm-testing-roborazzi)
}
```

The `abm-testing-roborazzi` convention plugin (defined in `android-base-gradle-plugin/`) applies `io.github.takahirom.roborazzi` and adds `testImplementation` for:

- `roborazzi`
- `roborazzi-compose` — **not `roborazzi-compose-android`** (absent from Nexus)
- `robolectric`

All versions come from `gradle/libs.versions.toml`.

## Test AndroidManifest

Create `src/test/AndroidManifest.xml` (Android-only modules) or `src/androidUnitTest/AndroidManifest.xml` (KMP modules):

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="<app.package.id>">
    <application android:theme="@style/Theme.AppCompat">
        <activity android:name="androidx.activity.ComponentActivity"
            android:theme="@style/Theme.AppCompat" />
    </application>
</manifest>
```

Both attributes are mandatory:

- `xmlns:android` — omitting it causes `prefix 'android' not bound` at manifest parse.
- `package` — without it Robolectric uses `org.robolectric.default` and cannot resolve `ComponentActivity`.

## Test pattern

Use `captureRoboImage(filePath) { composable }`, **not** `createAndroidComposeRule<ComponentActivity>()`. No `AlfaTheme { }` wrapper in the test — the composable's own default token values are used. Write one `@Test` per screen state listed in the plan (Loading, Error, Content variants, Empty); pass explicit state instances, do not rely on data class defaults.

```kotlin
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "w360dp-h800dp-xxhdpi")
class <Screen>ScreenshotTest {

    @Test
    fun content() {
        captureRoboImage("screenshots/<Screen>-content.png") {
            <Screen>Content(state = <State>(/* content fixture */), onAction = {})
        }
    }

    @Test
    fun loading() {
        captureRoboImage("screenshots/<Screen>-loading.png") {
            <Screen>Content(state = <State>(isLoading = true), onAction = {})
        }
    }

    @Test
    fun error() {
        captureRoboImage("screenshots/<Screen>-error.png") {
            <Screen>Content(state = <State>(error = "..."), onAction = {})
        }
    }
}
```

## Why `@Config(sdk = [33])`

Higher SDK levels cause `NoSuchMethodError` in Compose text rendering under Robolectric. `createAndroidComposeRule<ComponentActivity>()` triggers activity-resolution failures in AGP 8+ even with a correct manifest; the direct `captureRoboImage { }` API avoids this.

## Running tests

```bash
./gradlew :<module>:testDebugUnitTest                                  > swarm-report/<slug>-stage-5-test.log 2>&1
./gradlew :<module>:testDebugUnitTest -Proborazzi.test.record=true     # first run / no prior snapshot
```
