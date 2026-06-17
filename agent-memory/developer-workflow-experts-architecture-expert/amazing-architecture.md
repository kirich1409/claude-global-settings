---
name: amazing-architecture
description: Architecture of :amazing Compose Desktop module — Decompose nav stack, MVIKotlin stores, Metro DI, IPA source abstraction (IpaFile sealed interface, IpaService, BundledApps)
type: project
---

Module :amazing = Compose Desktop GUI (ios-install repo). Stack: Decompose (nav) + MVIKotlin (state) + Metro DI.

**Navigation (RootComponent, StackNavigation<Config>):** Connect → SelectIpa → Install → Done. Linear wizard; `configToIndex` maps each Config to sidebar step 0-3. Config carries data forward: `SelectIpa(device)` → `Install(device, ipas)` → `Done(result)`.

**IPA source abstraction (the key boundary for remote-download feature):**
- `IpaFile` sealed interface (domain/) — `displayName` + `toFile(): File?`. Two impls: `Bundled(app)` (resolves via `BundledApps.fileFor`) and `Custom(file)`. This is the seam where a remote source plugs in: `toFile()` is the late-binding point Install uses.
- `BundledApp` data class carries fileName/displayName/version/iconFileName/account. `BundledApps` object is a hardcoded `list` + resolves files from `compose.application.resources.dir` system property (packaged) or dev fallback paths.
- `IpaService` interface: `getAvailableBundledApps()`, `pickIpaFile()`, `iconFor()`. DefaultIpaService is stateless, reads BundledApps directly.
- Install consumes IPA purely via `ipa.toFile()` in InstallStoreFactory.installItem — it never knows bundled vs custom vs remote. Clean boundary.

**Key integration facts:**
- SelectIpaStoreFactory pre-selects first bundled app in initialState (`selectedIpas = setOf(IpaFile.Bundled(bundledApps.first()))`).
- WizardResult.installedApps only counts `IpaFile.Bundled` (casts `it.ipa as? IpaFile.Bundled`) — remote IpaFile variant must carry BundledApp-equivalent metadata or this loses data.
- Metro DI: AppGraph @DependencyGraph, Providers BindingContainer. Services provided here (DeviceService singleton, IpaService non-scoped). appScope = SupervisorJob + Dispatchers.Default.

**Dependencies:** :amazing → :protocol only. No network lib in :amazing. okhttp 4.12.0 is in version catalog but used only by :sms-forwarder. kotlinx.serialization NOT present anywhere.

**Bundled IPA files are huge:** INSNC 1.68 = 218 MB, Бизнес = 125 MB in appResources/common/ — shipped inside the app bundle. This is the motivation for remote download (shrink installer, update IPAs without app rebuild).
