# Migration Summary: RefRequestAuditorFragment (DataBinding -> ViewBinding + StateFlow)

## Files Modified

### 1. `reference/reference-impl/src/main/res/layout/fragment_reference_auditor_request.xml`
- Removed `<layout>` wrapper and `<data>` section (variables: viewModel, dateFormatter, dataModel)
- Removed all binding expressions: `app:bind_alfaInputText`, `app:bind_error`, `app:bind_hasError`, `app:bind_inputChangeListener`, `app:bind_singleClickListener`, `app:bind_inputVisibility`, `app:onFocusChangeListener`, `app:onAddClickListener`, `android:text="@{...}"`
- Added `android:id` to views that had bindings but no id:
  - `@+id/frar_address` (address AlfaInputView)
  - `@+id/frar_copies_number` (copies number AlfaInputView)
  - `@+id/frar_email_switch` (AlfaSwitchInputView)
- Removed static `android:text` from confirm button (now set programmatically)

### 2. `reference/reference-impl/src/main/kotlin/.../RefRequestAuditorDataModel.kt`
- Converted `address: ObservableField<String>()` -> `MutableStateFlow("")`
- Converted `addressError: ObservableError()` -> `MutableStateFlow(ErrorState())`
- Converted `copiesNumber: ObservableField<String>()` -> `MutableStateFlow("")`
- Converted `copiesNumberError: ObservableError()` -> `MutableStateFlow(ErrorState())`
- Kept `attachmentError` as `ObservableError` (used as one-shot event source for message dialogs, not as view-bound error)
- Did NOT modify `BaseRefDataModel` fields (shared by 6+ sibling screens)

### 3. `reference/reference-impl/src/main/kotlin/.../RefRequestAuditorFragment.kt`
- Replaced DataBinding inflation with ViewBinding: `viewBinding(FragmentReferenceAuditorRequestBinding::bind)` delegate
- `onCreateView` now returns `FragmentReferenceAuditorRequestBinding.inflate(inflater, container, false).root`
- All setup moved to `onViewCreated`, organized into:
  - `setupViews()` - static view config (link movement method)
  - `setupListeners()` - click/text/focus listeners
  - `setupObservers()` - StateFlow collection with `repeatOnLifecycle(STARTED)`
  - `setupBaseModelCallbacks()` - ObservableField callbacks for BaseRefDataModel fields
  - `observeLiveData()` - ViewModel LiveData observation
- **Loop guards** on every two-way binding:
  - `address` flow: `if (viewBinding.frarAddress.text != text)`
  - `copiesNumber` flow: `if (viewBinding.frarCopiesNumber.text != text)`
  - `email` callback: `if (viewBinding.frarEmailSwitch.inputText != text)`
  - `notifyEmail` callback: `if (viewBinding.frarEmailSwitch.getInputVisibility() != visible)`
- **Initial values** set after every `addOnPropertyChangedCallback` for base model fields
- **Lifecycle cleanup** in `onDestroyView`: all 4 ObservableField callbacks removed
- Used `getFirstViewWithError(root, container)` standalone function instead of DataBinding extension
- Used `setSingleClickListener` from `base-ktx` (existing), `textChanges` from `ui-components` (existing)
- Used `applyError` from new shared extensions

### 4. `reference/reference-impl/src/main/kotlin/.../RefRequestAuditorViewModel.kt`
- Updated `takeFormData()`: `.get()` -> `.value` for address/copiesNumber (removed `?` since MutableStateFlow<String> is non-null)
- Updated `processSuccessInitial()`: `.set()` -> `.value =` for address/copiesNumber, added `.orEmpty()` for null safety
- Updated `onAddressFocusChanged()`: `.get()` -> `.value`
- Updated `onCopiesNumberFocusChanged()`: `.get()?.toIntOrNull()` -> `.value.toIntOrNull()`
- Left base model fields (notifyEmail, email) using `.get()`/`.set()` since they remain as ObservableField/ObservableBoolean

### 5. `reference/reference-impl/src/main/kotlin/.../RefRequestAuditorValidationHelper.kt`
- `addressError.enable(text)` -> `addressError.value = ErrorState.enabled(text)`
- `addressError.disable()` -> `addressError.value = ErrorState.disabled()`
- `copiesNumberError.enable(text)` -> `copiesNumberError.value = ErrorState.enabled(text)`
- `copiesNumberError.disable()` -> `copiesNumberError.value = ErrorState.disabled()`
- Left `attachmentError` calls unchanged (still ObservableError)

## Files Created

### 6. `documents-host/document/src/androidMain/kotlin/.../ErrorState.kt`
- New standalone `data class ErrorState` in the document module (shared location)
- Has `companion object` with `enabled(text)` and `disabled()` factory methods
- Placed next to `ObservableError.kt` for discoverability
- Will be reused by all future migrated screens

### 7. `documents-host/document/src/androidMain/kotlin/.../ViewBindingExtensions.kt`
- `AlfaInputView.applyError(error: ErrorState)` - sets `hasError` tag + error text
- `AlfaSwitchInputView.applyError(error: ErrorState)` - sets `hasError` tag + inputError
- `getFirstViewWithError(root: View, container: LinearLayout?)` - non-DataBinding equivalent of the existing `ViewDataBinding.getFirstViewWithError()`
- All functions properly set `hasError` tag (required for error-focus navigation)

## Key Design Decisions

1. **BaseRefDataModel left untouched** - 6+ sibling DataModels extend it; modifying would break all other reference screens still on DataBinding
2. **ObservableField callbacks with lifecycle cleanup** - base model fields observed via `addOnPropertyChangedCallback` with removal in `onDestroyView` to prevent leaks
3. **attachmentError kept as ObservableError** - it's used as a one-shot event source (auto-reset pattern in `observe {}` extension), not displayed in a view
4. **Shared extensions in document module** - `applyError` and `getFirstViewWithError` placed in shared location to avoid duplication across future migrations
5. **Existing extension functions reused** - `setSingleClickListener` from base-ktx, `textChanges` from ui-components, `hasError` from base-ktx
