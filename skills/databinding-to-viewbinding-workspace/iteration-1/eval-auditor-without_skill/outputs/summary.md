# Migration Summary: RefRequestAuditorFragment (DataBinding -> ViewBinding + StateFlow)

## Files Modified

### 1. Layout: `reference/reference-impl/src/main/res/layout/fragment_reference_auditor_request.xml`
- Removed `<layout>` / `<data>` wrapper and all DataBinding variables (`viewModel`, `dateFormatter`, `dataModel`)
- Removed all `app:bind_*` DataBinding expressions (`bind_alfaInputText`, `bind_error`, `bind_hasError`, `bind_inputChangeListener`, `bind_inputVisibility`, `bind_singleClickListener`)
- Removed all `app:onFocusChangeListener` DataBinding lambda expressions
- Removed `app:onAddClickListener` DataBinding expression from `AlfaBagListView`
- Removed `android:text="@{dataModel.confirmText}"` from confirm button
- Added IDs to views that need programmatic access: `frar_address`, `frar_copies_number`, `frar_email`
- Layout is now a plain ViewBinding-compatible XML (no `<layout>` tag)

### 2. DataModel: `reference/reference-impl/src/main/kotlin/.../requestauditor/RefRequestAuditorDataModel.kt`
- Replaced `ObservableField<String>` with `MutableStateFlow<String?>(null)` for `address` and `copiesNumber`
- Replaced `ObservableError` with `MutableStateFlow(ErrorState())` for `addressError`, `attachmentError`, `copiesNumberError`
- Removed imports: `androidx.databinding.ObservableField`, `by.st.alfa.ib2.document.presentation.ObservableError`
- Added imports: `kotlinx.coroutines.flow.MutableStateFlow`, `ErrorState`

### 3. Base DataModel: `reference/reference-impl/src/main/kotlin/.../base/BaseRefDataModel.kt`
- Replaced `ObservableBoolean` with `MutableStateFlow(false)` for `notifyEmail`
- Replaced `ObservableField<String>` with `MutableStateFlow<String?>(null)` for `email` and `confirmText`
- Replaced `ObservableError` with `MutableStateFlow(ErrorState())` for `emailError`
- Added `ErrorState` data class (immutable, replaces mutable `ObservableError.ErrorState`)
- Added `MutableStateFlow<ErrorState>.enable(errorText)` extension function
- Added `MutableStateFlow<ErrorState>.disable()` extension function
- Removed imports: `androidx.databinding.ObservableBoolean`, `androidx.databinding.ObservableField`, `ObservableError`

### 4. ViewModel: `reference/reference-impl/src/main/kotlin/.../requestauditor/RefRequestAuditorViewModel.kt`
- Replaced `ObservableField.get()` with `.value` in `takeFormData()`, `onAddressFocusChanged()`, `onCopiesNumberFocusChanged()`
- Replaced `ObservableField.set()` / `ObservableBoolean.set()` with `.value =` in `processSuccessInitial()`
- Replaced `ObservableError.observe { }` (DataBinding callback-based) with `StateFlow.filter { it.isActive }.onEach { ... }.launchIn(viewModelScope)` in `init` block
- Replaced `ObservableError.enable()` call in `createAttachment()` error handler with extension function
- Removed import: `by.st.alfa.ib2.document.presentation.observe`
- Added imports: `viewModelScope`, `ErrorState`, `enable`, coroutines flow operators

### 5. Base ViewModel: `reference/reference-impl/src/main/kotlin/.../base/BaseRefViewModel.kt`
- Replaced `dataModel.confirmText.set(it)` with `dataModel.confirmText.value = it`
- Replaced `dataModel.notifyEmail.listenPositiveState { ... }` with `dataModel.notifyEmail.filter { it }.onEach { ... }.launchIn(viewModelScope)`
- Replaced `dataModel.email.get()` / `dataModel.notifyEmail.get()` with `.value` in `onEmailFocusChanged()`
- Removed import: `by.st.alfa.ib2.document.presentation.listenPositiveState`
- Added imports: `viewModelScope`, `kotlinx.coroutines.flow.filter/launchIn/onEach`

### 6. ValidationHelper: `reference/reference-impl/src/main/kotlin/.../requestauditor/RefRequestAuditorValidationHelper.kt`
- No logic changes needed - `enable()`/`disable()` calls continue to work via new extension functions
- Added imports for `enable` and `disable` extension functions from `base` package

### 7. Base ValidationHelper: `reference/reference-impl/src/main/kotlin/.../base/BaseRefValidationHelper.kt`
- No logic changes needed - `enable()`/`disable()` extension functions are in the same package
- Removed unused import: `by.st.alfa.ib2.reference_impl.R`

### 8. Fragment: `reference/reference-impl/src/main/kotlin/.../requestauditor/RefRequestAuditorFragment.kt`
- Replaced DataBinding inflation (`FragmentReferenceAuditorRequestBinding.inflate` + `binding.viewModel/lifecycleOwner/dataModel/dateFormatter`) with ViewBinding inflation (just `inflate`)
- Organized setup into helper methods: `setupTextListeners()`, `setupFocusListeners()`, `setupClickListeners()`, `observeLiveData()`, `observeStateFlows()`
- Text change listeners: `AlfaInputView.textChanges { }` writes to `MutableStateFlow.value` and clears error state
- Switch listener: `AlfaSwitchInputView.setOnCheckedChangeListener { }` writes to `notifyEmail` flow
- Focus listeners: `setOnFocusChangeListener { }` calls ViewModel validation methods
- Click listeners: `setOnAddClickListener { }` and `OnSingleClickListener.wrap { }` for confirm button
- StateFlow collection: Uses `viewLifecycleOwner.lifecycleScope.launch { repeatOnLifecycle(STARTED) { ... } }` pattern with separate coroutines for each flow
- Collects text flows (address, copiesNumber, email) for ViewModel -> View sync (replaces two-way DataBinding)
- Collects error flows to set `hasError` tag and `error`/`inputError` properties
- Collects `notifyEmail` flow to call `setInputVisibility()`
- Collects `confirmText` flow to set button text
- Replaced `binding.getFirstViewWithError()` (DataBinding extension) with local `findFirstViewWithError()` that iterates children by `hasError` tag
- Removed imports: `FragmentReferenceAuditorRequestBinding` DataBinding class (now using ViewBinding-generated class with same name), `getFirstViewWithError`
- Added imports: `Lifecycle`, `lifecycleScope`, `repeatOnLifecycle`, `hasError`, `OnSingleClickListener`, `textChanges`, `ErrorState`, `AlfaInputView`, `AlfaSwitchInputView`

## Breaking Changes (Expected)

Changing `BaseRefDataModel` from `ObservableField`/`ObservableBoolean`/`ObservableError` to `MutableStateFlow` affects all sibling reference fragments that still use DataBinding:
- `RefStatementFragment` / `RefStatementDataModel`
- `RefOtherFragment` / `RefOtherDataModel`
- `RefCashFlowFragment` / `RefCashFlowDataModel`
- `RefCardLoanFragment` / `RefCardLoanDataModel`
- `RefAccountStateFragment` / `RefAccountStateDataModel`

These siblings need the same migration pattern applied to compile successfully.

## Key Patterns Used

| Before (DataBinding) | After (ViewBinding + StateFlow) |
|---|---|
| `ObservableField<String>()` | `MutableStateFlow<String?>(null)` |
| `ObservableBoolean()` | `MutableStateFlow(false)` |
| `ObservableError()` | `MutableStateFlow(ErrorState())` |
| `field.get()` | `field.value` |
| `field.set(value)` | `field.value = value` |
| `error.enable(text)` | `error.enable(text)` (extension function) |
| `error.disable()` | `error.disable()` (extension function) |
| `error.observe { }` | `error.filter { it.isActive }.onEach { ... }.launchIn(scope)` |
| `observable.listenPositiveState { }` | `flow.filter { it }.onEach { ... }.launchIn(scope)` |
| `app:bind_alfaInputText="@={...}"` | `view.textChanges { }` + `flow.collect { view.text = it }` |
| `app:bind_error="@{...}"` | `errorFlow.collect { view.error = ... }` |
| `app:bind_hasError="@{...}"` | `errorFlow.collect { view.hasError = ... }` |
| `app:bind_inputChangeListener` | `view.textChanges { }` or `view.addTextChangedListener { }` |
| `app:bind_singleClickListener` | `OnSingleClickListener.wrap { }` |
| `app:onFocusChangeListener` | `view.setOnFocusChangeListener { }` |
| `app:onAddClickListener` | `view.setOnAddClickListener { }` |
| `binding.getFirstViewWithError()` | local `findFirstViewWithError(parent)` |
