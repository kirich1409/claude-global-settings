# RefCardLoanFragment: DataBinding to ViewBinding + StateFlow Migration Summary

## Files Changed

### Modified Files

1. **`reference/reference-impl/src/main/res/layout/fragment_reference_card_loan.xml`**
   - Removed `<layout>` wrapper and `<data>` section (variables: dataModel, viewModel, dateFormatter)
   - Removed all binding expressions: `app:bind_text`, `app:bind_error`, `app:bind_singleClickListener`, `app:bind_alfaInputText`, `app:bind_hasError`, `app:bind_inputChangeListener`, `app:bind_inputVisibility`, `app:onFocusChangeListener`, `android:text="@{...}"`
   - Added `android:id="@+id/frcl_date_on"` to the date TwoLineChooseView
   - Added `android:id="@+id/frcl_email_switch"` to the AlfaSwitchInputView
   - Removed `android:text="@{dataModel.confirmText}"` from the confirm Button (text set programmatically)
   - Kept all static XML attributes (`app:tcv_textHint`, `app:alfaSwitchInput*`, styles, etc.)

2. **`reference/reference-impl/src/main/kotlin/.../cardloan/RefCardLoanDataModel.kt`**
   - Converted `dateOn` from `ObservableField<Calendar?>()` to `MutableStateFlow<Calendar?>(null)`
   - Converted `dateOnError` from `ObservableError()` to `MutableStateFlow(ErrorState())`
   - Removed imports for `ObservableField` and `ObservableError`; added imports for `ErrorState` and `MutableStateFlow`
   - Left base class fields (`email`, `emailError`, `notifyEmail`, `confirmText`) untouched in `BaseRefDataModel` since 5 other screens still use it with DataBinding

3. **`reference/reference-impl/src/main/kotlin/.../cardloan/RefCardLoanViewModel.kt`**
   - `dateOn.get()` / `dateOn.set()` replaced with `dateOn.value`
   - `dateOnError.disable()` replaced with `dateOnError.value = ErrorState.disabled()`
   - Base class fields (`email.get()`, `notifyEmail.get()`, `email.set()`, `notifyEmail.set()`) left as-is (still ObservableField API)
   - Added import for `ErrorState`

4. **`reference/reference-impl/src/main/kotlin/.../cardloan/RefCardLoanValidationHelper.kt`**
   - `dateOnError.enable(text)` replaced with `dateOnError.value = ErrorState.enabled(text)`
   - `dateOnError.disable()` replaced with `dateOnError.value = ErrorState.disabled()`
   - Added import for `ErrorState`

5. **`reference/reference-impl/src/main/kotlin/.../cardloan/RefCardLoanFragment.kt`**
   - Replaced DataBinding inflation with ViewBinding: `FragmentReferenceCardLoanBinding.inflate(...)` in `onCreateView`, delegate `by viewBinding(FragmentReferenceCardLoanBinding::bind)`
   - Removed `binding.viewModel`, `binding.lifecycleOwner`, `binding.dataModel`, `binding.dateFormatter` assignments
   - **StateFlow observation** (dateOn, dateOnError): lifecycle-aware via `repeatOnLifecycle(STARTED)` + `collect`
   - **Base class ObservableField observation** (confirmText, email, emailError, notifyEmail): `addOnPropertyChangedCallback` with named callback objects, initial value setting after callback registration, cleanup in `onDestroyView`
   - **Loop guards**: email callback checks `inputText != text`; notifyEmail callback checks `getInputVisibility() != visible`
   - **Listeners**: click via `OnSingleClickListener.wrap`; `setOnCheckedChangeListener` for switch two-way; `addTextChangedListener` for email two-way + error clearing; `setOnFocusChangeListener` for email validation
   - **Error focus**: replaced `binding.getFirstViewWithError(binding.frclRequisites)` with standalone `getFirstViewWithError(viewBinding.frclRequisites)`
   - Removed import for `by.st.alfa.ib2.document.presentation.getFirstViewWithError` (was DataBinding-based)

### New Files

6. **`documents-host/document/src/androidMain/kotlin/by/st/alfa/ib2/document/presentation/ErrorState.kt`**
   - Created once in the document module, shared across all future migrated screens
   - `data class ErrorState(isActive, errorText)` with `enabled()` / `disabled()` companion factories

7. **`reference/reference-impl/src/main/kotlin/.../edit/ViewBindingExtensions.kt`**
   - `getFirstViewWithError(container: LinearLayout): View?` -- non-DataBinding replacement for the one in `BindingExtensions.kt`
   - `TwoLineChooseView.applyError(error: ErrorState)` -- sets `hasError` tag + shows/hides error text
   - `AlfaSwitchInputView.applyError(error: ErrorState)` -- sets `hasError` tag + `inputError`
   - All marked `internal` to the module

## Key Design Decisions

- **BaseRefDataModel left untouched**: 5 other reference screens (RefCashFlow, RefStatement, RefOther, RefRequestAuditor, RefAccountState) still use DataBinding with the same base class. Converting it would break them all. Instead, the migrated fragment observes base class fields via `addOnPropertyChangedCallback`.
- **BaseRefViewModel left untouched**: It uses `ObservableBoolean.listenPositiveState` and `ObservableField.set()` on base data model fields. These remain functional.
- **ErrorState created in document module**: Per skill instructions, placed once at `by.st.alfa.ib2.document.presentation.ErrorState` so all migrated screens can share it. It is distinct from the inner `ObservableError.ErrorState` class (which still exists for non-migrated screens).
- **build.gradle.kts not modified**: `useDataBinding = true` is still required because other screens in the module use DataBinding. `useViewBinding = true` and `viewBindingPropertyDelegate` were already present.

## Pitfalls Addressed

| Pitfall | How Addressed |
|---------|---------------|
| Two-way binding loops | Loop guard on email callback (`inputText != text`) and notifyEmail callback (`getInputVisibility() != visible`) |
| Initial value after callback registration | Explicit initial value set for all 4 base model fields after `addOnPropertyChangedCallback` |
| Lifecycle cleanup for callbacks | All 4 callbacks removed in `onDestroyView()` before `super.onDestroyView()` |
| `hasError` tag in applyError | Both `TwoLineChooseView.applyError` and `AlfaSwitchInputView.applyError` set `hasError` first |
| ErrorState placement | Created once in document module, not per-screen |
| Shared extensions not duplicated | `applyError` and `getFirstViewWithError` placed in module-level `ViewBindingExtensions.kt`, not per-fragment |
| Base class not modified | BaseRefDataModel and BaseRefViewModel untouched; base fields observed via callbacks |
