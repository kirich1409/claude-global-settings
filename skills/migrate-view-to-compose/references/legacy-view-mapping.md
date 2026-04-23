# Legacy custom Views → UIKit / abm-uikit-ext mapping

Lookup for Stage 1 of the migration. The table maps **project-specific legacy custom Views** (`by.st.alfa.ib2.ui_components.*`) to their recommended replacement in the new UI Kit — so the implementer does not re-derive these each time and does not silently fall back to Material.

Scope: widgets actually used in the repo under `by.st.alfa.ib2.ui_components.view.*` and `by.st.alfa.ib2.ui_components.common.*`. If a legacy View is not in the table, treat it as a gap → Stage 2 Missing-components gate.

## Confidence levels

- **Likely** — direct 1:1 mapping exists; use as drop-in with parameter translation.
- **Probable** — close match; verify API of the target before committing.
- **Unknown / gap** — no obvious UIKit equivalent; run Stage 2 Missing-components gate (Option A composition / B UIKit request / C approved `AndroidView` for complex widgets only).

Confidence is a heuristic — always confirm the target component's API against the design-system sources (`libs.abm.designsystem`, `abm-uikit-ext`) before writing code. See `uikit-mapping.md` for the authoritative token + component lookup.

## Mapping

| Legacy class (`by.st.alfa.ib2.ui_components.*`) | Purpose | Recommended replacement | Confidence | Notes |
|---|---|---|---|---|
| `view.AlfaInputView` | Labeled text input | `uikit_ext.field.InputField` (pre-configured wrapper matching legacy behaviour); drop to core `components.field.TextField` (`TextFieldState`-based) for bespoke cases | Likely | `alfaInputHint` → `label`; `alfaInputMaxLength` / `alfaInputSymbols` → `inputTransformation` (NOT `visualTransformation`); for numbers prefer `components.field.NumberField` or `TextField` + `NumberInputTransformation` / `NumberOutputTransformation`. |
| `view.InputPasswordView` | Password input with toggle | `by.alfabank.uikit.components.field.SecureTextField` | Likely | Drop-in for masked input with reveal affordance. |
| `view.PhoneInputView` | Masked phone number | `uikit_ext.field.PhoneField` (preferred — pre-configured Belarus +375 input); or core `components.field.TextField(inputTransformation = PhoneNumberInputTransformation, outputTransformation = PhoneNumberOutputTransformation)` for custom flows | Likely | `PhoneField` is the ready widget; the core transformations pair lives in `components.field.transformation.phone`. |
| `view.AmountInputView` | Currency amount input | `uikit_ext.field.AmountField` (preferred — pre-configured currency input); or `components.field.NumberField` / `TextField` + `NumberInputTransformation` / `NumberOutputTransformation`. Display-only: `components.amount.AmountText` / `AmountHeadline` | Likely | `AmountField` already wraps `NumberField` with the right format — use it for input, `AmountText` for read-only display. |
| `view.AlfaPickerView` | Dropdown / picker | `by.alfabank.uikit.components.form.Select` | Likely | `Select` is a form primitive — correct package is `form`, not `field`. Scrolling date / time → `components.calendar.DatePicker`. |
| `view.AlfaSearchView` | Search box | `uikit_ext.field.SearchField` | Likely | Ready search field; do not hand-roll `TextField + MagnifierM` when this widget exists. |
| `view.AlfaSwitchView` | Row with label + switch | `uikit_ext.field.LabeledSwitch` (or `SwitchInput` for form-row style) | Likely | Direct drop-in. |
| `view.TwoTabView` | Two-segment tab selector | `components.SegmentedControl` | Likely | Segmented selector (core, not ext). |
| `view.TwoLineChooseView` | Row: title + subtitle + trailing chevron | `uikit_ext.field.ChooseField` | Likely | Direct drop-in. |
| `view.SettingsItemView` | Row for a settings entry | `uikit_ext.field.DetailsLineItem` (read-only) or `ChooseField` (actionable) | Likely | Pick by interactivity. |
| `common.InfoBlockView` | Info banner | `uikit_ext.block.InfoBlock` for structured content; `components.plate.Plate` for a one-line notice | Likely | Prefer `InfoBlock` when the legacy view has title + body + icon. |
| `view.SnackBarView` | Transient notification | `by.alfabank.uikit.components.snackbar.Snackbar` + `SnackbarHost` | Likely | AlfaTheme ships its own `Snackbar` with a Material-like API — use it directly. Do not fall back to `Plate` or Material `SnackbarHost`. |
| `view.filter.FilterView` | Row of filter chips | `uikit_ext.filter.FilterChipRow` | Likely | Direct drop-in. |
| `view.bottomsheet.BottomSheetTitleView` | Bottom-sheet root with title | `ModalBottomSheet` + `NavigationBar(title = ...)` | Likely | The title becomes the `NavigationBar` slot inside `ModalBottomSheet`. |
| `view.bottomsheet.BottomSheetRecycler` | Bottom-sheet list | `ModalBottomSheet` + `LazyColumn` | Likely | Adapter items → composable rows. |
| `view.TitleWithIconView` | Section title with leading icon | `uikit_ext.block.BlockTitle*` (the `oneIcon` / `twoIcons` variants); fall back to `Row` + `Icon` + `Text(style = headline.*)` if no variant fits | Likely | `BlockTitle` ships pre-designed variants. |
| `view.StepperView` | Multi-step progress indicator (dots / counter) | `by.alfabank.uikit.components.Steps` with `OrderedStep` / `UnorderedStep` / `StepConnector` | Likely | Direct replacement — core primitive. |
| `view.PaymentStepNavigator` | Step navigation for payment flow | `uikit_ext.navigation.StepNavigationBar` | Likely | Direct replacement — ready widget. |
| `view.SmsView` | OTP / SMS code input grid | `uikit_ext.field.SmsCodeField` (preferred — ready widget); or core `components.confirmation.OtpTextField` (+ `rememberOtpTextFieldState`) for bespoke flows | Likely | `SmsCodeField` wraps `OtpTextField` with the project's UX. |
| `view.AlfaBagListView` | Tag-cloud / chip list | `uikit_ext.filter.FilterChipRow` (preferred when behaviour matches filters); otherwise `LazyRow` / `FlowRow` of `components.Chip` | Probable | Target depends on selection / wrap behaviour. |
| `view.AlfaDocumentView` | Document row / upload | `components.file.FileUploadView` for upload flows; `uikit_ext.document.DocumentListCard` for a list entry; `components.data.DataView` for a read-only preview row | Likely | Pick by role. |
| `view.ProgressImageView` | Image with loading overlay | `uikit_ext.image.CircleImageLoader` for round-avatar use; otherwise `Box` + `Image` + `components.skeleton.Skeleton` overlay | Likely | `CircleImageLoader` is the ready avatar loader (see line below). |
| `view.MBEditText` | Plain edit text with branding | `uikit_ext.field.InputField` or core `components.field.TextField` | Likely | Thinner than `AlfaInputView`; `InputField` covers it. |
| `view.NonAuthEditText` | Edit text used on dark auth screens | `uikit_ext.field.InputField` wrapped in `AlfaTheme(mode = Mode.Dark)` (when `## Theme decision` = Dark) | Probable | Otherwise the regular light `InputField` / `TextField`. |

## Legacy custom avatars / images

| Legacy class | Purpose | Recommended replacement | Confidence | Notes |
|---|---|---|---|---|
| `CompanyImageView` (and similar round-avatar views used across the app) | Round company / user avatar with loading | `uikit_ext.image.CircleImageLoader` (preferred — ready round avatar with loader); or `components.iconview.IconView` (+ `IconViewShape` / badges) for an icon-tile look | Likely | `CircleImageLoader` matches the typical avatar behaviour (network / placeholder / loader); `IconView` is for icon-shaped tiles. |

## Using this table

- Stage 1 mapping: for every custom view the XML references, find its row here and copy the *Recommended replacement* into the per-View mapping line of the plan. Confidence = Likely → proceed. Confidence = Probable → verify the target API first. Confidence = Unknown / gap → Stage 2.
- Do not silently substitute a Material component if the row is Unknown — that violates non-negotiable #2.
- If the target UIKit component does not yet exist, follow `missing-components-decision.md` Option B (UIKit-team request with a stubbed local composable).

## Extending the table

When a migration uncovers a new legacy custom view not listed here, add a row after resolving it through Stage 2 — so the next migration finds it quickly. Update the confidence column to `Likely` once the mapping has survived one full migration end-to-end without revision.
