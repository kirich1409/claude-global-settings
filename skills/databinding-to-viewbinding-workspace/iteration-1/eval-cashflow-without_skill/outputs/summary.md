# Migration Summary: RefCashFlowFragment (DataBinding -> ViewBinding + StateFlow)

## Files Changed

### 1. Layout: `reference/reference-impl/src/main/res/layout/fragment_reference_cash_flow.xml`

- Removed `<layout>` wrapper and `<data>` block (variables: `dateFormatter`, `dataModel`, `viewModel`)
- Removed all DataBinding expressions (`@{}`, `@={}`) from XML attributes
- Removed DataBinding-specific attributes: `app:bind_error`, `app:bind_singleClickListener`, `app:bind_text`, `app:bind_alfaInputText`, `app:bind_hasError`, `app:bind_inputChangeListener`, `app:bind_inputVisibility`, `app:onFocusChangeListener`, `app:headerLeftText` (expression), `app:onAddClickListener` (expression)
- Added `android:id` to previously anonymous views that need programmatic access:
  - `@+id/frcf_start_date` (TwoLineChooseView for start date)
  - `@+id/frcf_end_date` (TwoLineChooseView for end date)
  - `@+id/frcf_switch_input` (AlfaSwitchInputView for email)
- Kept static XML attributes (`app:tcv_hasDivider`, `app:tcv_textHint`, `app:ablv_button_name`, etc.)
- Result: plain ViewBinding-compatible layout (no `<layout>` tag)

### 2. DataModel: `reference/reference-impl/src/main/kotlin/.../RefCashFlowDataModel.kt`

- **Kept** existing `ObservableField`/`ObservableError` fields (required for `BaseRefDataModel`/`BaseRefViewModel`/`BaseRefValidationHelper` compatibility)
- **Added** StateFlow mirrors for each observable field:
  - `startDateFlow: StateFlow<Calendar?>` (mirrors `startDate: ObservableField<Calendar?>`)
  - `endDateFlow: StateFlow<Calendar?>` (mirrors `endDate: ObservableField<Calendar?>`)
  - `startDateErrorFlow: StateFlow<ErrorState?>` (mirrors `startDateError: ObservableError`)
  - `endDateErrorFlow: StateFlow<ErrorState?>` (mirrors `endDateError: ObservableError`)
  - `emailFlow: StateFlow<String?>` (mirrors `email: ObservableField<String>` from base)
  - `emailErrorFlow: StateFlow<ErrorState?>` (mirrors `emailError: ObservableError` from base)
  - `notifyEmailFlow: StateFlow<Boolean>` (mirrors `notifyEmail: ObservableBoolean` from base)
  - `confirmTextFlow: StateFlow<String?>` (mirrors `confirmText: ObservableField<String>` from base)
- **Added** `update*Flow()` methods for each StateFlow
- **Added** `ErrorState` data class as a Kotlin-native replacement for `ObservableError.ErrorState`

### 3. ViewModel: `reference/reference-impl/src/main/kotlin/.../RefCashFlowViewModel.kt`

- **Added** `syncObservableFieldsToStateFlows()` method that registers `OnPropertyChangedCallback` on each `ObservableField`/`ObservableError`/`ObservableBoolean` to forward changes to the corresponding StateFlow
- **Added** `onEmailTextChanged(text: String)` -- called from Fragment when user types in the email input; updates `dataModel.email` and disables error (replaces two-way `@={dataModel.email}` + `bind_inputChangeListener`)
- **Added** `onNotifyEmailChanged(isChecked: Boolean)` -- called from Fragment when user toggles the switch (replaces two-way `@={dataModel.notifyEmail}`)
- **Added** `toFlowErrorState()` extension on `ObservableError` to convert to `RefCashFlowDataModel.ErrorState`
- Existing methods (`takeFormData`, `processSuccessInitial`, `onDateSelected`, etc.) unchanged -- they still use `ObservableField.get()`/`.set()` which triggers the sync callbacks

### 4. Fragment: `reference/reference-impl/src/main/kotlin/.../RefCashFlowFragment.kt`

- **Removed** all DataBinding usage:
  - No more `FragmentReferenceCashFlowBinding.inflate()` as DataBinding (now generates ViewBinding class)
  - Removed `binding.viewModel = ...`, `binding.lifecycleOwner = ...`, `binding.dataModel = ...`, `binding.dateFormatter = ...`
  - Removed `binding.getFirstViewWithError(...)` (DataBinding extension)
- **Added** programmatic click listeners replacing BindingAdapter expressions:
  - `binding.frcfStartDate.setSingleClickListener { viewModel.onStartDateClick() }`
  - `binding.frcfEndDate.setSingleClickListener { viewModel.onEndDateClick() }`
  - `binding.frcfConfirm.setOnClickListener(OnSingleClickListener.wrap { ... })`
  - `binding.frcfListView.setOnAddClickListener { ... }`
- **Added** programmatic listeners for AlfaSwitchInputView (replacing two-way DataBinding):
  - `addTextChangedListener` -> `viewModel.onEmailTextChanged(text)`
  - `setOnCheckedChangeListener` -> `viewModel.onNotifyEmailChanged(isChecked)`
  - `setOnFocusChangeListener` -> `viewModel.onEmailFocusChanged(hasFocus)`
- **Added** `lifecycleScope.launch + repeatOnLifecycle(STARTED)` block collecting 8 StateFlows:
  - Start/end date text (formatted via `dateFormatter`)
  - Start/end date errors
  - Email text, email error, notify email visibility
  - Confirm button text
- **Added** LiveData observer for `currentItemsSizeText` to update `headerLeftText`
- **Added** private extension functions (replacing BindingAdapters):
  - `TwoLineChooseView.setSingleClickListener(action)` -- wraps `setOnClickListener`
  - `TwoLineChooseView.applyErrorState(errorState)` -- applies error or clears it, sets `hasError` tag
  - `AlfaSwitchInputView.applyErrorState(errorState)` -- sets/clears `inputError`, sets `hasError` tag
  - `AlfaSwitchInputView.setInputTextIfChanged(text)` -- guards against redundant setText loops
  - `AlfaSwitchInputView.setInputVisibilityIfChanged(isVisible)` -- guards against redundant toggle
  - `LinearLayout.getFirstChildWithError()` -- replaces `ViewDataBinding.getFirstViewWithError`

## Design Decisions

1. **BaseRefDataModel not modified** -- shared by other screens (`RefAccountStateFragment`, `RefCardLoanFragment`, `RefOtherFragment`, `RefRequestAuditorFragment`, `RefStatementFragment`). Modifying it would require migrating all sibling screens simultaneously.

2. **Bridge pattern (ObservableField -> StateFlow)** -- `syncObservableFieldsToStateFlows()` in ViewModel registers property-change callbacks to push updates to StateFlows. This keeps `BaseRefViewModel` and `BaseRefValidationHelper` working unchanged while the Fragment consumes only StateFlows.

3. **build.gradle.kts unchanged** -- `useDataBinding = true` remains because 17 other files in `reference-impl` still use DataBinding. Removing it is a separate task.

4. **Extension functions are file-private** -- placed at bottom of Fragment file since they are specific to this screen's view types. If more screens adopt the same pattern, they can be extracted to a shared utility.
