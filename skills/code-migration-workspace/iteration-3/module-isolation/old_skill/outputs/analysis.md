# Migration Analysis: Retrofit+OkHttp → Ktor

## Summary

Your networking layer is currently mixed into `:app` alongside UI fragments and ViewModels. Migrating directly from Retrofit to Ktor in-place would create an extended period where two HTTP clients coexist in the same module, making the migration hard to review, test, or roll back. The recommended approach is a **two-phase migration**: first extract the networking code into a dedicated Gradle module, then perform the Retrofit-to-Ktor swap inside that isolated module.

---

## Phase 1 — Extract Networking to a Dedicated Gradle Module

### Why this must come first

Mixing the client swap with the extraction makes every PR larger, harder to review, and riskier to revert. Isolation gives you:

- A clear boundary: `:network` (or `:data:network`) owns all HTTP concerns
- `:app` depends on interfaces, not concrete HTTP clients — the swap in Phase 2 becomes invisible to UI code
- ProGuard rules can be scoped to the new module's consumer-rules file

### What to move

| File | Destination |
|---|---|
| `RetrofitClient.kt` | `:network` (will be replaced in Phase 2) |
| `UserService.kt` | `:network` |
| `OrderService.kt` | `:network` |
| `ProductService.kt` | `:network` |
| `PaymentService.kt` | `:network` |
| `AuthService.kt` | `:network` |

Define Kotlin interfaces for each service and expose only those interfaces from `:network`. `:app` depends on the interfaces, not the Retrofit implementations.

### ProGuard / R8 — hidden consumers to flag

The existing ProGuard rules in `:app` reference service classes directly (e.g., `-keep class com.example.UserService`). These are **hidden consumers**: they encode knowledge of the concrete networking implementation inside the app module's build configuration, which will silently break if the class names change or the classes move.

Actions required:
1. Move the keep rules for service classes and `RetrofitClient` into a `consumer-rules.pro` file inside the new `:network` module. Gradle will automatically merge consumer rules from library modules into the app's R8 configuration.
2. After Phase 2, update or remove rules that referenced Retrofit-specific classes (`retrofit2.**`, `okhttp3.**`, `okio.**`) — they will no longer apply.
3. Add keep rules for Ktor's serialization classes if you use `kotlinx.serialization` (Ktor's default) — the serializer reflection paths need to be preserved.

---

## Phase 2 — Ktor Implementation Inside `:network`

### Retrofit/OkHttp artifacts and their Ktor equivalents

| Retrofit+OkHttp concept | Ktor equivalent |
|---|---|
| `Retrofit` builder + `OkHttpClient` | `HttpClient { }` builder (CIO, OkHttp, or Android engine) |
| `@GET`, `@POST`, `@Path`, `@Query` annotations | `client.get(urlString) { parameter(...) }` — explicit call-site DSL |
| `Converter.Factory` (Gson/Moshi/kotlinx) | `ContentNegotiation` plugin + `json(Json { })` |
| `CallAdapter.Factory` (Coroutines/RxJava) | Native `suspend` support — no adapter needed |
| `OkHttpClient.Builder` interceptors (logging) | `Logging` plugin (`install(Logging)`) |
| `Authenticator` / token refresh interceptor | `Auth` plugin (`install(Auth) { bearer { ... } }`) |
| `HttpLoggingInterceptor` | `Logging { level = LogLevel.ALL }` |
| `OkHttp` cache | `HttpCache` plugin |
| Timeout config on `OkHttpClient` | `install(HttpTimeout) { requestTimeoutMillis = ... }` |

### Key dependency changes

Remove from `:network`:
```
com.squareup.retrofit2:retrofit
com.squareup.retrofit2:converter-gson (or moshi/kotlinx)
com.squareup.okhttp3:okhttp
com.squareup.okhttp3:logging-interceptor
```

Add to `:network`:
```
io.ktor:ktor-client-core
io.ktor:ktor-client-cio          # or ktor-client-android / ktor-client-okhttp
io.ktor:ktor-client-content-negotiation
io.ktor:ktor-serialization-kotlinx-json
io.ktor:ktor-client-logging
io.ktor:ktor-client-auth         # if token refresh is needed
```

Ktor version at time of writing: **2.3.x** (stable). The `io.ktor` group ID is consistent across all artifacts.

Note: if you choose `ktor-client-okhttp` as the engine (to reuse OkHttp's connection pooling or certificate pinning), OkHttp itself remains a transitive dependency — you keep the networking behavior but remove the Retrofit annotation layer.

### Service file migration pattern

Retrofit services are interface + annotation driven. Ktor services become plain classes with `HttpClient` injected:

```kotlin
// Before (Retrofit)
interface UserService {
    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDto
}

// After (Ktor)
class UserService(private val client: HttpClient, private val baseUrl: String) {
    suspend fun getUser(id: String): UserDto =
        client.get("$baseUrl/users/$id").body()
}
```

Repeat for `OrderService`, `ProductService`, `PaymentService`, `AuthService`.

---

## Recommended PR Breakdown

### PR 1 — Module extraction (no behavior change)

- Create `:network` Gradle module
- Move all 6 files into `:network`
- Define service interfaces; `:app` uses interfaces only
- Move ProGuard keep rules to `:network/consumer-rules.pro`
- `:app` `build.gradle` gains `implementation(project(":network"))`, loses direct Retrofit/OkHttp deps

**Risk**: Low. This is a structural refactor with no logic changes. CI proves nothing broke.

### PR 2 — Ktor implementation inside `:network`

- Replace `RetrofitClient.kt` with an `HttpClient` builder
- Rewrite each `*Service.kt` as a Ktor class (interfaces remain unchanged, so `:app` is untouched)
- Swap Retrofit/OkHttp deps for Ktor deps in `:network/build.gradle`
- Update `consumer-rules.pro` for Ktor/kotlinx.serialization keep rules
- Add or update unit tests for each service using `MockEngine`

**Risk**: Medium. Contained entirely within `:network`. `:app` code is unchanged. Rollback = revert this one PR.

### PR 3 — Cleanup

- Remove any remaining Retrofit/OkHttp references (transitive dependency exclusions if needed)
- Delete dead code (old converter factories, interceptor wrappers, etc.)
- Remove now-unnecessary ProGuard rules for Retrofit classes
- Update documentation / architecture diagrams

---

## Risk Flags

1. **ProGuard rules referencing service class names** — must be migrated to `consumer-rules.pro` before Phase 1 is merged, or R8 will silently drop keep rules after the move.
2. **`kotlinx.serialization` requires the Kotlin serialization plugin** — add `kotlin("plugin.serialization")` to `:network/build.gradle` and ensure model DTOs are annotated with `@Serializable`. If DTOs currently use Gson/Moshi without annotations, they will need updates.
3. **`AuthService` / token refresh** — if the current `OkHttpClient` uses an `Authenticator` for 401 token refresh, the Ktor `Auth` plugin handles this differently. Audit the refresh logic before PR 2.
4. **SSL / certificate pinning** — if `OkHttpClient` has a custom `SSLSocketFactory` or `CertificatePinner`, use `ktor-client-okhttp` engine to preserve that configuration, or replicate it via the CIO engine's `https { }` block.
