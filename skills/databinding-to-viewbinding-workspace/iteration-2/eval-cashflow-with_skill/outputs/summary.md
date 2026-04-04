# RefCashFlowFragment: DataBinding to ViewBinding + StateFlow Migration Summary

## Files Changed

### New files created

1. **`documents-host/document/src/androidMain/kotlin/by/st/alfa/ib2/document/presentation/ErrorState.kt`**
   - Shared `data class ErrorState` with `isActive`, `errorText` fields and `enabled()`/`disabled()` companion factory methods.
   - Created ONCE in the document module (next to `ObservableError.kt`) for reuse by all migrated screens.

2. **`documents-host/document/src/androidMain/kotlin/by/st/alfa/ib2/document/presentation/ViewBindingExtensions.kt`**
   - Shared extension functions for ViewBinding-based screens:
     - `View.getFirstViewWithError(container: LinearLayout)` — replacement for the DataBinding-dependent version in `BindingExtensions.kt`.
     - `View.setOnSingleClickListener(listener: () -> Unit)` — wraps with `OnSingleClickListener`.
     - `TwoLineChooseView.applyError(error: ErrorState)` — sets `hasError` tag + shows/hides error text.
     - `AlfaInputView.applyError(error: ErrorState)` — sets `hasError` tag + error property.
     - `AlfaSwitchInputView.applyError(error: ErrorState)` — sets `hasError` tag + `inputError` property.
   - All `applyError` functions set the `hasError` tag (required for `getFirstViewWithError` focus navigation).

### Modified files

3. **`reference/reference-impl/src/main/res/layout/fragment_reference_cash_flow.xml`**
   - Removed `<layout>` wrapper, `<data>` section, and all binding expressions.
   - Added `android:id` to views that needed programmatic access: `frcf_start_date`, `frcf_end_date`, `frcf_email_switch`.
   - Removed `app:headerLeftText` and `app:onAddClickListener` binding expressions from `AlfaBagListView` (now set programmatically).
   - Removed `android:text` binding from the confirm button (now set via `addOnPropertyChangedCallback`).
   - Kept all static XML attributes (`app:tcv_hasDivider`, `app:alfaSwitchInputHint`, etc.).

4. **`reference/reference-impl/src/main/kotlin/.../RefCashFlowDataModel.kt`**
   - Converted own fields from `ObservableField`/`ObservableError` to `MutableStateFlow`:
     - `accountsError`: `ObservableError` -> `MutableStateFlow<ErrorState>`
     - `startDate`: `ObservableField<Calendar?>` -> `MutableStateFlow<Calendar?>(null)`
     - `startDateError`: `ObservableError` -> `MutableStateFlow<ErrorState>()`
     - `endDate`: `ObservableField<Calendar?>` -> `MutableStateFlow<Calendar?>(null)`
     - `endDateError`: `ObservableError` -> `MutableStateFlow<ErrorState>()`
   - Left `selectedAccounts` as `MutableLiveData` (it's observed as LiveData in Fragment/ViewModel).
   - **Did NOT modify `BaseRefDataModel`** — it is shared by 5+ other screens that still use DataBinding.

5. **`reference/reference-impl/src/main/kotlin/.../RefCashFlowViewModel.kt`**
   - Replaced `ObservableError.observe { }` with `MutableStateFlow.filter { it.isActive }.onEach { ... }.launchIn(viewModelScope)`.
   - Updated all `.get()` -> `.value` for `startDate`, `endDate`.
   - Updated all `.set(value)` -> `.value = value` for `startDate`, `endDate`.
   - Updated all `.enable(text)` -> `.value = ErrorState.enabled(text)` and `.disable()` -> `.value = ErrorState.disabled()` for `startDateError`, `endDateError`.

6. **`reference/reference-impl/src/main/kotlin/.../RefCashFlowValidationHelper.kt`**
   - Updated all `ObservableError` API calls to `MutableStateFlow<ErrorState>` API:
     - `.enable(text)` -> `.value = ErrorState.enabled(text)`
     - `.disable()` -> `.value = ErrorState.disabled()`

7. **`reference/reference-impl/src/main/kotlin/.../RefCashFlowFragment.kt`**
   - Added ViewBinding delegate: `private val viewBinding by viewBinding(FragmentReferenceCashFlowBinding::bind)`
   - Changed `onCreateView` to inflate via ViewBinding: `FragmentReferenceCashFlowBinding.inflate(inflater, container, false).root`
   - Moved setup to `onViewCreated` with clear separation:
     - `setupListeners()` — click handlers, text change listeners, focus listener, keyboard observer.
     - `setupBaseModelObservers()` — `addOnPropertyChangedCallback` for base class `ObservableField`/`ObservableBoolean`/`ObservableError` fields (`confirmText`, `email`, `emailError`, `notifyEmail`) with initial value setting after registration.
     - `setupStateFlowObservers()` — `repeatOnLifecycle(STARTED)` collection for migrated `MutableStateFlow` fields (`startDate`, `startDateError`, `endDate`, `endDateError`).
     - `setupLiveDataObservers()` — standard `observe(viewLifecycleOwner)` for LiveData events.
   - Added `onDestroyView()` — removes all 4 `OnPropertyChangedCallback` instances to prevent memory leaks.
   - `AlfaBagListView.headerLeftText` now set via `currentItemsSizeText` LiveData observer (was XML binding expression).
   - `AlfaBagListView.setOnAddClickListener` now called in `setupListeners()`.
   - `getFirstViewWithError` now uses the new ViewBinding-compatible extension.

## Key Design Decisions

1. **BaseRefDataModel NOT modified** — 5+ other DataBinding screens extend it. The migrated fragment observes base class fields via `addOnPropertyChangedCallback` with proper lifecycle cleanup.

2. **Loop guards on two-way bindings** — email text callback checks `inputText != text` before setting; notifyEmail callback checks `getInputVisibility() != visible` before setting. Switch and text listeners write back to ObservableField/ObservableBoolean.

3. **Initial value setting** — every `addOnPropertyChangedCallback` is followed by setting the initial value from the ObservableField, since callbacks only fire on future changes.

4. **hasError tag in every applyError** — all three `applyError` extensions set `view.hasError = error.isActive` to ensure `getFirstViewWithError()` focus navigation works.

5. **ErrorState created once** in the document module, not duplicated per-screen.

6. **Shared extensions not duplicated** — `applyError`, `setOnSingleClickListener`, `getFirstViewWithError` placed in `ViewBindingExtensions.kt` in the document module for reuse.
