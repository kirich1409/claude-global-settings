# RefCardLoanFragment: DataBinding to ViewBinding + StateFlow Migration Summary

## Files Changed

### 1. Layout: `reference/reference-impl/src/main/res/layout/fragment_reference_card_loan.xml`

- Removed `<layout>` wrapper and `<data>` block (variables: `dataModel`, `viewModel`, `dateFormatter`)
- Removed all `app:bind_*` and `app:onFocusChangeListener` data binding expressions from views
- Removed `android:text="@{dataModel.confirmText}"` from the confirm Button
- Added `android:id="@+id/frcl_date_on"` to the date TwoLineChooseView (previously had no ID)
- Added `android:id="@+id/frcl_email_switch"` to the AlfaSwitchInputView (previously had no ID)
- Layout is now a plain ViewBinding-compatible XML (root element is `LinearLayout`, not `<layout>`)

### 2. Data Model: `RefCardLoanDataModel.kt`

- Removed `androidx.databinding.ObservableField` import
- Removed `by.st.alfa.ib2.document.presentation.ObservableError` import
- Replaced `val dateOn = ObservableField<Calendar?>()` with `val dateOn = MutableStateFlow<Calendar?>(null)`
- Replaced `val dateOnError = ObservableError()` with `val dateOnError = MutableStateFlow(ErrorState())`
- Added nested `data class ErrorState(val isActive: Boolean = false, val errorText: String? = null)` as a replacement for `ObservableError.ErrorState`
- Still extends `BaseRefDataModel` (base fields `email`, `notifyEmail`, `emailError`, `confirmText` remain as `ObservableField`/`ObservableBoolean`/`ObservableError` since the base class is shared by other fragments)

### 3. ViewModel: `RefCardLoanViewModel.kt`

- `takeFormData()`: changed `dataModel.dateOn.get()` to `dataModel.dateOn.value`
- `processSuccessInitial()`: changed `dataModel.dateOn.set(...)` to `dataModel.dateOn.value = ...`
- `onDateSelected()`: changed `dataModel.dateOnError.disable()` to `dataModel.dateOnError.value = RefCardLoanDataModel.ErrorState()`, changed `dataModel.dateOn.set(date)` to `dataModel.dateOn.value = date`
- `onDateOnClick()`: changed `dataModel.dateOn.get()` to `dataModel.dateOn.value`
- No changes to base class fields access (`email.get()`, `notifyEmail.get()`, `email.set()`, `notifyEmail.set()` remain as ObservableField API)

### 4. Validation Helper: `RefCardLoanValidationHelper.kt`

- `handleDateOnValidationResult()`: replaced `dataModel.dateOnError.enable(text)` with `dataModel.dateOnError.value = RefCardLoanDataModel.ErrorState(isActive = true, errorText = text)`
- Replaced `dataModel.dateOnError.disable()` with `dataModel.dateOnError.value = RefCardLoanDataModel.ErrorState()`
- No changes to base class method `super.handleResult()` (still uses `ObservableError` for email validation via `BaseRefValidationHelper`)

### 5. Fragment: `RefCardLoanFragment.kt`

**Removed:**
- `onCreateView()` override (base class `BaseDocumentFragment.onCreateView` inflates via `layoutId`)
- `FragmentReferenceCardLoanBinding.inflate()` data binding setup
- `binding.viewModel`, `binding.lifecycleOwner`, `binding.dataModel`, `binding.dateFormatter` assignments
- `binding.getFirstViewWithError()` (was a `ViewDataBinding` extension)
- Imports: `LayoutInflater`, `ViewGroup`, `FragmentReferenceCardLoanBinding` (data binding), `getFirstViewWithError`

**Added:**
- `private val binding by viewBinding(FragmentReferenceCardLoanBinding::bind)` (ViewBinding delegate from `dev.androidbroadcast.vbpd`)
- `onViewCreated()` override as the new setup entry point
- `setupClickListeners()`: programmatic `OnSingleClickListener` for date picker and confirm button
- `setupEmailSwitchInput()`: programmatic listeners for checked change, text change, and focus change on `AlfaSwitchInputView`
- `observeViewModel()`: LiveData observers (same as before but using ViewBinding references)
- `observeStateFlows()`: coroutine-based collection of `dateOn` and `dateOnError` MutableStateFlows using `repeatOnLifecycle(STARTED)`
- `observeConfirmText()`: `OnPropertyChangedCallback` on base `ObservableField<String>` to update button text
- `observeNotifyEmail()`: `OnPropertyChangedCallback` on base `ObservableBoolean` to sync switch visibility
- `observeEmail()`: `OnPropertyChangedCallback` on base `ObservableField<String>` to sync email input text
- `observeEmailError()`: `OnPropertyChangedCallback` on base `ObservableError` to sync error state on email input
- Private top-level `getFirstViewWithError(LinearLayout)` function replacing the `ViewDataBinding` extension

**New imports:** `Lifecycle`, `lifecycleScope`, `repeatOnLifecycle`, `hasError`, `OnSingleClickListener`, `viewBinding`, `combine`, `launch`

## Files NOT Changed (Shared Base Classes)

- `BaseRefDataModel.kt` -- shared by all reference fragment types; still uses `ObservableField`/`ObservableBoolean`/`ObservableError`
- `BaseRefViewModel.kt` -- shared; still subscribes `buttonName` to `confirmText.set()` and uses `notifyEmail.listenPositiveState()`
- `BaseRefValidationHelper.kt` -- shared; still uses `ObservableError` for email validation
- `BaseRefFragment.kt` -- shared; no changes needed
- `build.gradle.kts` -- `useDataBinding = true` kept because other fragments in the module still use DataBinding

## Migration Strategy

This is a **localized migration** -- only the card loan screen was converted. The base data model and base ViewModel remain on ObservableField since they are shared by other reference fragments (accountstate, cashflow, other, requestauditor, statement). The fragment bridges between:

- **StateFlow** for card-loan-specific fields (`dateOn`, `dateOnError`) -- collected via `repeatOnLifecycle`
- **ObservableField callbacks** for base fields (`email`, `emailError`, `notifyEmail`, `confirmText`) -- observed via `addOnPropertyChangedCallback`
- **LiveData** for ViewModel events (`showMessage`, `requestDateAction`, `requestScrollDownAction`, `focusRequest`, `initInfoLink`) -- observed via `observe(viewLifecycleOwner)`

## Binding Adapter Replacements

| Original Binding Adapter | Replacement |
|---|---|
| `bind_singleClickListener` (on TwoLineChooseView) | `setOnClickListener(OnSingleClickListener.wrap { ... })` |
| `bind_singleClickListener` (on Button) | `setOnClickListener(OnSingleClickListener.wrap { ... })` |
| `bind_text` + `bind_error` (on TwoLineChooseView) | `combine(dateOn, dateOnError).collect { setText/setError/showError }` |
| `bind_alfaInputText` (two-way, on AlfaSwitchInputView) | `addTextChangedListener { email.set(text) }` + `observeEmail { inputText = text }` |
| `bind_error` + `bind_hasError` (on AlfaSwitchInputView) | `observeEmailError { inputError = errorText; hasError = isActive }` |
| `bind_inputChangeListener` (on AlfaSwitchInputView) | Inline in `addTextChangedListener { emailError.disable() }` |
| `bind_inputVisibility` (two-way, on AlfaSwitchInputView) | `setOnCheckedChangeListener { notifyEmail.set(it) }` + `observeNotifyEmail { setInputVisibility(it) }` |
| `onFocusChangeListener` (on AlfaSwitchInputView) | `setOnFocusChangeListener { viewModel.onEmailFocusChanged(it) }` |
| `android:text="@{confirmText}"` (on Button) | `observeConfirmText { button.text = it }` |
