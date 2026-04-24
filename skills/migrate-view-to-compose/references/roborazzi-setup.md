# Roborazzi module setup

Loaded when Pre-flight step 4 reports `NEEDS SETUP`. One-time per module — idempotent.

## Build configuration

Add the convention plugin, three test dependencies, and enable Android resources in unit tests:

```kotlin
// <module>/build.gradle.kts
plugins {
    // existing plugins...
    alias(libs.plugins.abm.testing.roborazzi)
}

android {
    // existing android {} config...
    testOptions {
        unitTests {
            isIncludeAndroidResources = true   // required — resolves stringResource() / R.* in Robolectric
        }
    }
}

dependencies {
    // Android-only module:
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)   // NOT roborazzi-compose-android (absent from Nexus)
    testImplementation(libs.robolectric)
    // KMP module: use androidUnitTest source-set deps instead:
    //   androidUnitTest.dependencies {
    //       implementation(libs.roborazzi)
    //       implementation(libs.roborazzi.compose)
    //       implementation(libs.robolectric)
    //   }
}
```

`isIncludeAndroidResources = true` is mandatory when the composable uses `stringResource(R.string.*)` — without it Robolectric throws `Resources$NotFoundException`.

The `abm-testing-roborazzi` convention plugin (defined in `android-base-gradle-plugin/`) applies `io.github.takahirom.roborazzi`. Test deps go in the module because `testImplementation` is only available after the android/java plugin is applied (which happens in the module, not in the precompiled script plugin).

All versions come from `gradle/libs.versions.toml`.

## Test AndroidManifest

Create `src/test/AndroidManifest.xml` (Android-only modules) or `src/androidUnitTest/AndroidManifest.xml` (KMP modules):

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:theme="@style/Theme.AppCompat">
        <activity android:name="androidx.activity.ComponentActivity"
            android:theme="@style/Theme.AppCompat" />
    </application>
</manifest>
```

Required:

- `xmlns:android` — omitting it causes `prefix 'android' not bound` at manifest parse.
- `<activity android:name="androidx.activity.ComponentActivity">` — Robolectric needs this registered to resolve the Compose host activity.

**Do NOT add a `package=` attribute.** AGP 9.0 rejects manifest `package` in library test sources — the namespace is derived from the module's `android.namespace` in `build.gradle.kts`.

## Test pattern

Use `captureRoboImage(filePath) { AlfaTheme { composable } }`, **not** `createAndroidComposeRule<ComponentActivity>()`. Wrap the composable in `AlfaTheme { }` — without it `LocalColorScheme` has no value and `AlfaTheme.colors.*` throws `IllegalStateException: No value provided!`. Write one `@Test` per screen state listed in the plan (Loading, Error, Content variants, Empty); pass explicit state instances, do not rely on data class defaults.

```kotlin
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "w360dp-h800dp-xxhdpi")
class <Screen>ScreenshotTest {

    @Test
    fun content() {
        captureRoboImage("screenshots/<Screen>-content.png") {
            AlfaTheme {
                <Screen>Content(state = <State>(/* content fixture */), onAction = {})
            }
        }
    }

    @Test
    fun loading() {
        captureRoboImage("screenshots/<Screen>-loading.png") {
            AlfaTheme {
                <Screen>Content(state = <State>(isLoading = true), onAction = {})
            }
        }
    }

    @Test
    fun error() {
        captureRoboImage("screenshots/<Screen>-error.png") {
            AlfaTheme {
                <Screen>Content(state = <State>(error = "..."), onAction = {})
            }
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
