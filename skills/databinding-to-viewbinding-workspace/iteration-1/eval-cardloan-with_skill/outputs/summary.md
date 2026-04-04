# RefCardLoanFragment: DataBinding to ViewBinding + StateFlow Migration Summary

## Files Changed

### 1. RefCardLoanDataModel.kt
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cardloan/RefCardLoanDataModel.kt`

- Replaced `ObservableField<Calendar?>` (`dateOn`) with `MutableStateFlow<Calendar?>(null)`
- Replaced `ObservableError` (`dateOnError`) with `MutableStateFlow(ErrorState())`
- Removed imports: `androidx.databinding.ObservableField`, `by.st.alfa.ib2.document.presentation.ObservableError`
- Added import: `kotlinx.coroutines.flow.MutableStateFlow`
- Added `ErrorState` data class in the same file (companion with `enabled()`/`disabled()` factory methods)
- **Did NOT convert `BaseRefDataModel` fields** (`email`, `emailError`, `notifyEmail`, `confirmText`) because `BaseRefDataModel` is shared by 6 other DataModel subclasses that still use DataBinding

### 2. fragment_reference_card_loan.xml
**Path:** `reference/reference-impl/src/main/res/layout/fragment_reference_card_loan.xml`

- Removed `<layout>` wrapper tag
- Removed `<data>` section with all `<variable>` declarations
- Removed all `app:bind_*` attributes and `@{}`/`@={}` binding expressions (11 total)
- Removed `android:text="@{dataModel.confirmText}"` from the confirm button
- Added `android:id="@+id/frcl_date_on"` to the date TwoLineChooseView (needed for programmatic access)
- Added `android:id="@+id/frcl_switch_email"` to the AlfaSwitchInputView (needed for programmatic access)
- Kept all static XML attributes (`app:tcv_*`, `app:alfaSwitchInput*`, styles, etc.)

### 3. RefCardLoanFragment.kt
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cardloan/RefCardLoanFragment.kt`

- Replaced DataBinding inflation with ViewBinding: `FragmentReferenceCardLoanBinding.inflate()` in `onCreateView`, `viewBinding(FragmentReferenceCardLoanBinding::bind)` delegate
- Moved all setup from `onCreateView` to `onViewCreated`
- **`setupObservers()`**: Collects `dateOn` and `dateOnError` StateFlows using `repeatOnLifecycle(STARTED)` pattern
- **`setupListeners()`**: Click listeners via `OnSingleClickListener.wrap {}`, checked/text change listeners on `AlfaSwitchInputView`
- **`setupBaseObservableCallbacks()`**: Observes the 4 base `ObservableField`/`ObservableBoolean`/`ObservableError` fields via `addOnPropertyChangedCallback` (since `BaseRefDataModel` is shared and cannot be migrated to StateFlow yet)
- Replaced `binding.getFirstViewWithError(binding.frclRequisites)` (DataBinding-dependent) with local `LinearLayout.getFirstChildWithError()` extension
- Added private `TwoLineChooseView.applyError(ErrorState)` extension function
- Removed unused imports: `ObservableError`, `AlfaSwitchInputView`

### 4. RefCardLoanViewModel.kt
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cardloan/RefCardLoanViewModel.kt`

- `dateOn.get()` -> `dateOn.value` (4 occurrences)
- `dateOn.set(...)` -> `dateOn.value = ...` (1 occurrence)
- `dateOnError.disable()` -> `dateOnError.value = ErrorState.disabled()` (1 occurrence)
- No changes to base class fields (`email.get()`, `notifyEmail.get()`, etc.) -- they remain as `ObservableField`/`ObservableBoolean`

### 5. RefCardLoanValidationHelper.kt
**Path:** `reference/reference-impl/src/main/kotlin/by/st/alfa/ib2/reference_impl/internal/presentation/edit/cardloan/RefCardLoanValidationHelper.kt`

- `dateOnError.enable(text)` -> `dateOnError.value = ErrorState.enabled(text)`
- `dateOnError.disable()` -> `dateOnError.value = ErrorState.disabled()`

## Key Design Decisions

1. **Partial migration of DataModel**: Only `RefCardLoanDataModel`'s own fields (`dateOn`, `dateOnError`) were converted to `MutableStateFlow`. The inherited `BaseRefDataModel` fields remain as `ObservableField`/`ObservableBoolean`/`ObservableError` because 5 other sibling DataModel classes depend on the base class. These are observed in the Fragment via `addOnPropertyChangedCallback`.

2. **ErrorState placement**: The `ErrorState` data class was placed in the same file as `RefCardLoanDataModel` since it's specific to this module's migration. When all reference screens are migrated, it can be extracted to a shared location.

3. **getFirstViewWithError replacement**: The original used `ViewDataBinding.getFirstViewWithError()` which calls `executePendingBindings()` first. Since we no longer have DataBinding, a simple `LinearLayout.getFirstChildWithError()` private extension was added that iterates direct children checking `hasError`.

4. **No build.gradle.kts changes**: The module still has other DataBinding layouts (other reference screens), so `useDataBinding = true` must remain.

## Build Config Status

- `reference/reference-impl/build.gradle.kts` already had `useViewBinding = true` and `viewBindingPropertyDelegate` dependency -- no changes needed
- `useDataBinding = true` retained because other screens in the module still use DataBinding
