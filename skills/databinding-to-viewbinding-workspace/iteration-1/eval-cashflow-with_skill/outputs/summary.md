# Migration Summary: RefCashFlowFragment (DataBinding -> ViewBinding + StateFlow)

## Files Changed

### 1. New File: `ErrorState.kt`
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cashflow/ErrorState.kt`

Created a simple `data class ErrorState` to replace `ObservableError` for the cashflow-specific fields. Placed in the `cashflow` package since `BaseRefDataModel` (shared across all reference screens) still uses `ObservableError`.

### 2. Modified: `RefCashFlowDataModel.kt`
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cashflow/RefCashFlowDataModel.kt`

- Converted `startDate` from `ObservableField<Calendar?>()` to `MutableStateFlow<Calendar?>(null)`
- Converted `startDateError` from `ObservableError()` to `MutableStateFlow(ErrorState())`
- Converted `endDate` from `ObservableField<Calendar?>()` to `MutableStateFlow<Calendar?>(null)`
- Converted `endDateError` from `ObservableError()` to `MutableStateFlow(ErrorState())`
- Converted `accountsError` from `ObservableError()` to `MutableStateFlow(ErrorState())`
- `selectedAccounts` remains as `MutableLiveData` (used as LiveData in ViewModel/Fragment)
- Still extends `BaseRefDataModel` which retains `ObservableField`/`ObservableBoolean`/`ObservableError` for `email`, `emailError`, `notifyEmail`, `confirmText` (shared with other reference screens)

### 3. Modified: `fragment_reference_cash_flow.xml`
**Path:** `reference/reference-impl/src/main/res/layout/fragment_reference_cash_flow.xml`

- Removed `<layout>` wrapper tag
- Removed `<data>` section with all `<variable>` declarations
- Removed all binding expressions: `app:bind_text`, `app:bind_error`, `app:bind_singleClickListener`, `app:bind_alfaInputText`, `app:bind_inputVisibility`, `app:bind_hasError`, `app:bind_inputChangeListener`, `app:onFocusChangeListener`, `app:headerLeftText`, `app:onAddClickListener`, `android:text="@{...}"`
- Added `android:id` attributes to views that lacked them but need programmatic access:
  - `@+id/frcf_start_date` (TwoLineChooseView for start date)
  - `@+id/frcf_end_date` (TwoLineChooseView for end date)
  - `@+id/frcf_switch_input` (AlfaSwitchInputView for email)
- Kept all static XML attributes (`app:tcv_textHint`, `app:alfaSwitchInputHint`, etc.)

### 4. Modified: `RefCashFlowFragment.kt`
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cashflow/RefCashFlowFragment.kt`

- Replaced DataBinding inflation with ViewBinding:
  - Added `private val viewBinding by viewBinding(FragmentReferenceCashFlowBinding::bind)` using `dev.androidbroadcast.vbpd`
  - `onCreateView` now inflates via `FragmentReferenceCashFlowBinding.inflate()`
- Moved all setup from `onCreateView` to `onViewCreated` with three setup methods:
  - `setupListeners()`: click listeners via `OnSingleClickListener.wrap`, switch/text change listeners, keyboard visibility
  - `setupObservers()`: StateFlow collection via `repeatOnLifecycle(STARTED)` for `startDate`, `startDateError`, `endDate`, `endDateError`; `addOnPropertyChangedCallback` for base model's `confirmText`, `notifyEmail`, `email`, `emailError`
  - `setupLiveDataObservers()`: all existing LiveData observations (showMessage, requestDateAction, requestAccountsAction, selectedAccounts, currentItemsSizeText, requestScrollDownAction, focusRequest, initInfoLink)
- Added `headerLeftText` programmatic update on `selectedAccounts` and `currentItemsSizeText` changes (was XML binding)
- Added `setOnAddClickListener` programmatic setup (was XML binding)
- Replaced `binding.getFirstViewWithError(binding.frcfRequisites)` (DataBinding extension) with a file-private `getFirstViewWithError(LinearLayout)` function that iterates children checking `View.hasError`
- Added file-private `TwoLineChooseView.applyError(ErrorState)` extension

### 5. Modified: `RefCashFlowViewModel.kt`
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cashflow/RefCashFlowViewModel.kt`

- Replaced `dataModel.accountsError.observe { ... }` (ObservableError extension) with `dataModel.accountsError.filter { it.isActive }.onEach { ... }.launchIn(viewModelScope)` (StateFlow-based)
- Changed `.set()` / `.get()` to `.value` for `startDate`, `endDate` fields
- Changed `.enable(text)` / `.disable()` to `ErrorState.enabled(text)` / `ErrorState.disabled()` for `startDateError`, `endDateError`
- Removed import of `by.st.alfa.ib2.document.presentation.observe`
- Added imports for `viewModelScope`, `filter`, `onEach`, `launchIn`

### 6. Modified: `RefCashFlowValidationHelper.kt`
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cashflow/RefCashFlowValidationHelper.kt`

- Changed `.enable(text)` to `.value = ErrorState.enabled(text)` for `accountsError`, `startDateError`, `endDateError`
- Changed `.disable()` to `.value = ErrorState.disabled()` for same fields

## Files NOT Changed (by design)

- **`BaseRefDataModel.kt`** -- Shared by 6+ other reference screens. Fields (`email`, `emailError`, `notifyEmail`, `confirmText`) remain as `ObservableField`/`ObservableBoolean`/`ObservableError`. Observed manually in the Fragment via `addOnPropertyChangedCallback`.
- **`BaseRefViewModel.kt`** -- Uses `dataModel.notifyEmail.listenPositiveState` and `dataModel.confirmText.set()` on the base model's ObservableField. Unchanged.
- **`BaseRefValidationHelper.kt`** -- Handles `emailError` via `ObservableError` API from `BaseRefDataModel`. Unchanged.
- **`BaseDocumentFragment.kt`** -- Abstract base with `layoutId`. The migrated fragment still provides `layoutId` (required by base class) but overrides `onCreateView` with ViewBinding inflation.
- **`build.gradle.kts`** -- Already has `useViewBinding = true` and `useDataBinding = true`. DataBinding cannot be removed yet because other screens in the module still use it.

## Key Design Decisions

1. **Partial DataModel migration**: Only `RefCashFlowDataModel`'s own fields were converted to StateFlow. Base model fields remain as ObservableField to avoid breaking other reference screens.
2. **Hybrid observation**: StateFlow fields use `repeatOnLifecycle(STARTED)` + `collect`. Base ObservableField fields use `addOnPropertyChangedCallback`. Both are lifecycle-safe.
3. **Two-way binding for email**: Replaced `@={dataModel.email}` + `@={dataModel.notifyEmail}` with manual listener -> set + callback -> update pattern with loop guards (`if (current != new)`).
4. **accountsError "fire-once" pattern**: The original `ObservableError.observe` extension consumed the error (reset `isActive = false`) after firing. The StateFlow replacement uses `filter { it.isActive }` + immediate reset to `ErrorState.disabled()` to preserve the same semantics.
