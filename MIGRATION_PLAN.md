# SwiftUI UI Migration Plan — Stage 1

## Scope and inspected baseline

Preparation only. This stage changes **only `MIGRATION_PLAN.md`**, directly on existing `main`; no branches, Swift/UI edits, project changes, or implementation.

- Native: [`kosaai/scannerapp`](https://github.com/kosaai/scannerapp), commit `9828235651450939fa6faef1c766881c26607005`.
- Lovable reference: [`kosaai/arabic-document-scanner`](https://github.com/kosaai/arabic-document-scanner), commit `df36cc59984e3db3b75d8fa489abfe53fa916a58`.
- Guidance used: installed **`swiftui-expert-skill`** (state ownership, navigation/presentation, adaptive layout, localization, API compatibility) and **`apple-hig`** (foundations, iOS, accessibility, RTL, typography, materials, privacy and file management).
- Evidence: source inspection of native app/models/viewmodels/services/views/utilities, `project.yml`, and reference routes/components/styles/editor state. No native compilation, simulator run, or hardware validation was performed on this Linux host.

## Existing architecture and behavior to preserve

Swift 6 / SwiftUI, iOS 18+, universal iPhone/iPad, MVVM with `@MainActor @Observable` viewmodels. `DocumentScannerApp.swift` supplies the SwiftData `ModelContainer`; view-owned models use `@State`, injected editable models use `@Bindable`, and document collections use `@Query`.

```text
HomeView (NavigationStack)
  ├─ ScannerView (fullScreenCover)
  │    ├─ DocumentCameraView / VisionKit on supported devices
  │    └─ PhotoImportView / PHPicker when unsupported, including Simulator
  ├─ ScanEditorView (fullScreenCover + NavigationStack)
  │    └─ PreviewView → ExportView
  │         └─ optional FilterView → ExportView
  ├─ LibraryView → DocumentDetailView
  └─ SettingsView (sheet)
```

- Capture produces ordered images; `ScannerViewModel` owns an in-memory `WorkingDocument` / `WorkingPage` draft. Add appends pages; successful Retake replaces the **whole draft**; canceled capture leaves it intact. Cancel discards; deleting the last page discards and dismisses.
- VisionKit supplies edge detection, perspective correction, auto-capture, corner adjustment, flash, retake and multipage capture. Keep this bridge and the unsupported-camera photo-import fallback.
- `ImageProcessor` renders from originals using rotation and eight persisted filters: Original, Auto, White Document, Black & White, Denoise, Brighten, Sharpen Text and Receipt. Preserve previews, default-filter settings and Apply Filter to All Pages.
- `OCRService` uses on-device Vision accurate recognition with language correction. Optional draft OCR and saved-document OCR feed stored page text, combined library-content search, and text copy/share. Arabic recognition support is **not verified**; Arabic UI does not imply Arabic OCR.
- `PDFService` creates image-based multipage PDFs with fit/A4/Letter sizing, orientation-aware aspect fit and configurable JPEG quality; it does **not** add a searchable text layer. Preserve PDF/JPG export, Photos, Files/iCloud Drive destination selection, and native sharing/AirDrop. Exporting is separate from **Save to Library**.
- SwiftData stores document/page metadata and cascade relationships; `Application Support/Scans/<document UUID>/` stores original/processed JPEGs and thumbnails. Preserve UUIDs, filenames, page order, filter raw values, OCR aggregates and UserDefaults keys. PDFs are generated on demand; Files/iCloud export is not cloud synchronization.
- Library supports name/OCR search, rename, deep duplicate, delete and PDF sharing. Saved detail is a viewer/OCR/export screen, **not an existing saved-document editor**. Preserve settings and all routes, including features absent from the reference.

## Reference analysis and screen mapping

Reference source paths below are relative to the Lovable repository; native paths are relative to `DocumentScannerApp/`.

| Design | Reference source | Existing SwiftUI destination and approach |
|---|---|---|
| Home | `src/routes/index.tsx`; `src/components/home/{HomeHeader,SearchBar,DocumentFilters,QuickActions,RecentDocuments,DocumentSortButton,BottomNav}.tsx` | `Views/HomeView.swift` for composition and capture/settings entry; `Views/LibraryView.swift` and `ViewModels/LibraryViewModel.swift` for real search/actions. Map recent cards and file rows to real `ScanDocument` thumbnails; keep saved-item navigation to detail. |
| Camera | `src/routes/scan.tsx`; `src/components/scan/{ScanScreen,CameraViewfinder}.tsx`, `use-camera.ts` | `Views/ScannerView.swift` + `Services/ScannerService.swift`. Retain system capture UI. Adapt surrounding entry/review presentation only; exact custom viewfinder/shutter parity is explicitly deferred. |
| Editor | `src/routes/editor.tsx`; `src/components/editor/{DocumentEditorScreen,EditorHeader,DocumentPreview,PageCounter,ZoomControl,EditorToolbar,FilterSheet,DeletePageSheet,SavePdfButton}.tsx`; `src/lib/document-editor.ts` | `Views/ScanEditorView.swift`, `PreviewView.swift`, `FilterView.swift`, `ExportView.swift`. Borrow title/page hierarchy, paper canvas, action grouping and filter-sheet treatment without replacing working-image state or collapsing the established flow initially. |

### Visual language to translate, not copy mechanically

`src/styles.css` defines a pale cool background, teal/mint primary gradient, white rounded surfaces, soft elevation, translucent controls, a dark camera surface, and a paper-on-canvas editor. Source anchors: background `oklch(0.975 0.006 240)`, primary `oklch(0.58 0.15 195)`, glow `oklch(0.72 0.13 175)`, paper `oklch(0.995 0.002 90)`, canvas `oklch(0.93 0.012 255)`, camera background `oklch(0.15 0.005 195)`, base radius `1.25rem`.

The web uses IBM Plex Sans Arabic, RTL layout, a 430px Home container, recent-paper cards, quick-action tiles, and a floating bottom bar with a raised Scan action. Editor uses a floating title bar, page counter, large save pill and five-action toolbar. These are reference proportions, **not fixed native screen dimensions**. Prefer scalable system typography/SF Arabic and SF Symbols; custom font bundling is not required. The stylesheet has no implemented `.dark` palette overrides, so native dark appearance must be designed and checked rather than inferred.

### Functional gaps and decisions

1. **Camera boundary:** `VNDocumentCameraViewController` owns its controls; the existing public bridge provides result/cancel/error callbacks, not custom shutter, torch, auto/manual or overlay styling. Keep VisionKit. Exact camera parity would require a separately approved AVFoundation/detection/perspective-correction project and regression suite—not a cosmetic reskin.
2. **Home is partly a prototype:** hard-coded documents and illustrated previews; search has no filtering handler; several quick actions, context actions, View All and non-scan navigation items are inert. Native data/actions remain authoritative. Map Home/Library/Settings/Scan to real routes; do not invent a Folders/Tools destination, QR/ID workflow, microphone search or cloud status. Expose photo import as a real additional action only in a later approved implementation.
3. **Category chips need semantics:** native models have no favorite/folder/tag/document-kind fields. Do not classify image-backed scans as distinct persisted PDF/image types merely to match sample chips. Defer unsupported chips/schema changes; preserve All and existing search. Any added name/date sorting can operate on existing metadata without changing persistence.
4. **Reference camera is real but transient:** browser capture/import/torch/review work, automatic capture is disabled, guides are decorative, images are not persisted or transferred to the editor. Never port these limitations into the native pipeline.
5. **Reference editor is not a PDF engine:** sample HTML pages, CSS filters/clipping, in-memory crop/rotate/zoom, and timer-based “Save PDF” feedback. Connect native controls to real images/services; no fake save confirmations. Keep all eight native filters rather than substituting the web's five CSS presets.
6. **Post-capture crop and saved editing are separate features:** native has no post-capture crop metadata or saved-document load/update editor path. Defer them; retain VisionKit corner adjustment and current detail behavior. Real crop would require normalized coordinates, rotation/orientation handling, model compatibility, pixel processing, thumbnail/export/OCR consistency and tests. Zoom may later be view-local, with no persistence change.
7. **Deletion and save semantics:** do not copy the web's “cannot delete last page” behavior. Preserve native final-page dismissal and separate PDF export versus library save; the visual primary action should initially open the existing Save & Share flow, not silently save or discard.

## File-by-file implementation plan (future stages only)

All existing paths below are under `DocumentScannerApp/`. “Preserve” means no implementation change is required for the first visual pass.

| File | Planned work / invariant |
|---|---|
| `Views/Components/ScannerTheme.swift` **(proposed new file)** | Centralize semantic teal/surface/canvas colors, radii, spacing and reusable surface/button styles; provide light/dark/contrast variants and iOS 18-compatible materials. Keep visual tokens separate from storage constants. |
| `Views/HomeView.swift` | First screen migration: header/search hierarchy, quick actions, real recent thumbnail cards and file rows; keep capture/editor ownership, empty state, Library/Settings access, branding/footer and DEBUG seed behavior. Initially retain current navigation rather than introducing duplicate stacks. |
| `Views/Components/DocumentRow.swift` | Restyle thumbnail, name, localized date and page count; preserve accessible combined label and stable document identity. Reuse metadata presentation for recent cards. |
| `Views/LibraryView.swift` | Align list/search/menus with Home styling; retain rename/duplicate/delete/share/detail routes, no-results state and existing search. |
| `ViewModels/LibraryViewModel.swift` | Reuse real name/OCR filtering and mutation methods; add metadata sorting only if approved, without modifying stored models. |
| `Views/ScannerView.swift` | Preserve VisionKit/import support switch and `[UIImage]` completion contract; no custom overlays obscuring system capture controls. |
| `Services/ScannerService.swift` | Preserve capture/import order, cancellation/failure callbacks and delegate isolation. Reuse `PhotoImportView` if an explicit Home import action is later authorized; do not replace VisionKit. |
| `Views/ScanEditorView.swift` | Keep one shared draft and whole-flow dismissal; host consistent editor surface styling. Do not add a second working document or saved-edit path. |
| `Views/PreviewView.swift` | Restyle paper canvas, page indicator and action grouping; keep real paging, add/delete/retake/cancel, final-page handling, direct Export and optional Adjust route. Clamp selection after mutations; use stable page IDs. |
| `Views/FilterView.swift` | Apply editor surface/toolbar styling; optionally present filter options as a native sheet in a later pass. Keep selected-page rotation, retake handoff, all presets, apply-to-all and Export. |
| `Views/Components/FilterThumbnail.swift` | Match rounded preview/selection treatment; retain actual processed thumbnails, labels and selection accessibility traits. |
| `Views/ExportView.swift` | Style title/actions to match the editor while retaining document naming, optional OCR, PDF/JPG/Photos/Files/share and explicit library save. Preserve item-bound URL sheet payloads and real completion/error feedback. |
| `Views/DocumentDetailView.swift` | Carry forward canvas/metadata styling; retain saved-page viewer, OCR rerun, copy/share text and every export destination. Do not route saved documents into new-document editing. |
| `Views/SettingsView.swift` | Apply shared styling only; keep PDF page-size/quality/default-filter preferences and version/about content. |
| `Views/Components/ShareSheet.swift` | Preserve native share activity wrapper and destinations. |
| `Views/Components/DocumentExporter.swift` | Preserve native Files/iCloud copy-export picker and completion/cancellation behavior. |
| `ViewModels/ScannerViewModel.swift` | Preserve working-state ownership, render caching, original images, add/retake/delete/apply-all/OCR/save/discard. Only add presentation-facing helpers if needed; no persistence redesign. |
| `Models/ScanDocument.swift` | Preserve schema, UUID directory identity, cascade relationship, ordered pages and cached count/OCR metadata. No favorites/tags fields in the visual pass. |
| `Models/ScanPage.swift` | Preserve file references, page order, filter/rotation/OCR metadata and image-loading fallbacks; no crop schema change. |
| `Models/FilterType.swift` | Preserve all persisted raw values, labels and eight-preset semantics; localization must not rename stored identifiers. |
| `Services/StorageService.swift` | Preserve original/processed/thumbnail writes, duplicate/delete lifecycle and model relationships. No file-layout migration. |
| `Utilities/ImageProcessor.swift` | Preserve real Core Image graphs and clockwise rotation used by preview/export; do not replace them with display-only effects. |
| `Services/OCRService.swift` | Preserve offline recognition; separately verify supported recognition languages on the target OS before promising Arabic OCR. |
| `Services/PDFService.swift` | Preserve real ordered multipage output, sizing/orientation and quality. No searchable-PDF or web-rendering substitution. |
| `Services/ExportService.swift` | Preserve real temporary PDF/JPG output, Photos authorization and image saving. |
| `Utilities/SettingsStore.swift` | Preserve UserDefaults keys, defaults and observable behavior. |
| `Utilities/Constants.swift` | Preserve application identity, directory/filename contracts, sizing and quality defaults; do not mix UI tokens into storage definitions. |
| `App/DocumentScannerApp.swift` | Preserve SwiftData container and root ownership; avoid a global forced RTL override. |
| `Utilities/DemoSeed.swift` | Preserve DEBUG/env-gated seeding; never substitute sample documents for real library content. |
| `Resources/Localizable.xcstrings` **(proposed, later localization pass)** | Add reviewed Arabic/English copy if Arabic implementation is approved, including accessibility labels, plurals and errors. Use locale-driven RTL, not hard-coded Arabic throughout the app. |
| `Resources/Assets.xcassets/AccentColor.colorset/Contents.json` | Later align accent variants with approved teal palette; preserve icons and resource structure. Not changed in Stage 1. |

`project.yml` uses the directory source `path: DocumentScannerApp` (despite CLAUDE.md describing an explicit file list). Future new files need XcodeGen regeneration, not an invented manual source list. Keep deployment target, Swift settings, bundle ID, signing, permissions, orientations, `Info.plist`, privacy manifest and export configuration unchanged during this preparation stage. A future test target/resource configuration change needs its own explicit scope.

## SwiftUI / HIG constraints

- HIG Layout: **“Respect system safe areas, margins, and guides; use layout modifiers to refine placement.”** Apply native toolbars/insets, not fixed web bottom padding; reflow on iPad/window resizing and Dynamic Type.
- HIG Branding: **“Express the brand with familiar components.”** Retain native navigation, sheets, controls and export pickers; a visual match does not justify dead controls or missing functions.
- HIG RTL: **“Avoid flipping photographs, illustrations, and general artwork: it can change meaning and may violate copyright.”** Mirror directional UI with leading/trailing and locale-aware navigation, never scanned pixels; verify mixed Arabic/Latin names, numerals, page order and VoiceOver reading order.
- Use accessible labels/selected states, scalable text, contrast checks and a project target of 44×44 pt hit areas; test Reduce Motion, Reduce Transparency and Increase Contrast. No remote font/network dependency for this offline app.
- Preserve `@State` ownership and `@Bindable` injection; keep business logic in existing models/services. Use item-driven presentation for payload-based sheets. Do not opportunistically rewrite unrelated APIs or introduce newer SDK requirements.
- Use standard materials for the reference's frosted treatment on iOS 18. Explicit Liquid Glass adoption is not requested; do not silently add iOS 26+ APIs or raise deployment requirements.

## Sequence, verification and next step

1. **Next implementation step, after approval:** establish baseline screenshots/smoke results on a Mac (iPhone + iPad; existing saved data), then implement shared theme and **Home only** using actual SwiftData documents and existing routes. Leave camera, editor, services and schemas untouched in that first implementation slice.
2. Restyle Library/rows, then Preview/Filter/Export with the shared tokens. Keep the current flow functional at every checkpoint. Carry compatible styling into saved detail/settings.
3. Implement reviewed Arabic resources/RTL as a dedicated pass; do not equate forced mirroring with localization. Any custom camera, post-capture crop, favorites/folders, QR/ID tools, saved editing or searchable PDF requires a separate approved scope.
4. On macOS, run `xcodegen generate` and build the existing `DocumentScannerApp` scheme for an available iOS simulator. No native test target is currently defined; propose automated coverage separately rather than claiming tests exist.
5. Regression gates: existing documents reopen after relaunch; no data loss; scan/import/cancel/error, add/retake/delete (including final page), all eight filters/rotation/apply-all, direct export and Adjust detour, PDF fit/A4/Letter/quality, JPG/Photos/Files/iCloud/share, explicit library save, OCR/content search/text copy/share, rename/duplicate/delete, and settings persistence. Hardware is required for VisionKit/flash/auto-capture/permissions; simulator import alone is insufficient.
6. Visual/accessibility gates: small/large iPhone, iPad/resizing, English LTR/Arabic RTL, mixed-script content, large Dynamic Type, VoiceOver, light/dark and accessibility appearance settings. Compare only real native states against the reference; document the intentional VisionKit camera difference.

**Pre-existing risks to track, not fix in Stage 1:** synchronous image/PDF/IO work on main-actor paths; ignored persistence/file errors; imported image orientation; OCR/save coordination and stale OCR after edits; separate boolean/payload sheets in Library/Detail versus item-bound Export sheets. These require focused validation and must not be hidden by visual changes.

**Stage 1 acceptance:** the only committed path is `MIGRATION_PLAN.md`; commit is on existing `main`, pushed to `origin/main`, and remote commit/file contents are read back. No claims of native build/runtime success are made.
