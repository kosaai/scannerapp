import SwiftUI
import SwiftData

/// Arabic-first Home only. Capture, editing and persistence remain in their existing screens/services.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanDocument.createdAt, order: .reverse) private var documents: [ScanDocument]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scannerVM = ScannerViewModel()
    @State private var libraryVM = LibraryViewModel()
    @State private var path: [HomeRoute] = []
    @State private var capture: CaptureSource?
    @State private var pendingEditor = false
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var scope = HomeScope.all
    @State private var sort = HomeSort.newest
    @FocusState private var searchFocused: Bool

    private enum HomeRoute: Hashable {
        case library
        case document(UUID)
    }

    private enum CaptureSource: String, Identifiable {
        case camera, photos
        var id: String { rawValue }
    }

    private enum HomeScope: String, CaseIterable, Identifiable {
        case all = "الكل"
        case recent = "الأخيرة"
        case multipage = "عدة صفحات"
        case recognized = "نص مستخرج"
        var id: Self { self }
    }

    private enum HomeSort: String, CaseIterable, Identifiable {
        case newest = "الأحدث أولاً"
        case oldest = "الأقدم أولاً"
        case name = "حسب الاسم"
        var id: Self { self }
    }

    private var matchingDocuments: [ScanDocument] {
        let searched = libraryVM.filter(documents)
        switch scope {
        case .all: return searched
        case .recent:
            let recentIDs = Set(documents.prefix(5).map(\.id))
            return searched.filter { recentIDs.contains($0.id) }
        case .multipage: return searched.filter { $0.pageCount > 1 }
        case .recognized:
            return searched.filter { !$0.combinedOCRText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    private var sortedDocuments: [ScanDocument] {
        switch sort {
        case .newest: return matchingDocuments
        case .oldest: return Array(matchingDocuments.reversed())
        case .name:
            return matchingDocuments.sorted {
                $0.name.compare($1.name, options: [.numeric, .caseInsensitive],
                                locale: Locale(identifier: "ar")) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeCanvas
                // Scoped to Home: do not force Arabic or mirror the camera/editor.
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .library:
                        LibraryView()
                            .toolbar(.visible, for: .navigationBar)
                    case .document(let id):
                        if let document = documents.first(where: { $0.id == id }) {
                            DocumentDetailView(document: document)
                                .toolbar(.visible, for: .navigationBar)
                        } else {
                            ContentUnavailableView("Document Unavailable", systemImage: "doc")
                                .toolbar(.visible, for: .navigationBar)
                        }
                    }
                }
                .fullScreenCover(item: $capture, onDismiss: captureDismissed) { source in
                    if source == .camera {
                        ScannerView(onComplete: captureCompleted)
                            .ignoresSafeArea()
                    } else {
                        PhotoImportView(onComplete: captureCompleted)
                            .ignoresSafeArea()
                    }
                }
                .fullScreenCover(isPresented: $showEditor) {
                    ScanEditorView(viewModel: scannerVM)
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack { SettingsView() }
                }
                .task {
                    #if DEBUG
                    // Existing opt-in screenshot hook only; normal Home never invents documents.
                    DemoSeed.seedIfNeeded(modelContext)
                    #endif
                }
        }
    }

    private var homeCanvas: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    quickActions.id("homeTop")
                    if documents.isEmpty {
                        emptyLibrary
                    } else if matchingDocuments.isEmpty {
                        noResults
                    } else {
                        recentSection
                        filesSection
                    }
                    footer
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                ScannerTheme.background.ignoresSafeArea()
                VStack {
                    Ellipse()
                        .fill(ScannerTheme.mint.opacity(0.09))
                        .frame(height: 220)
                        .blur(radius: 60)
                    Spacer()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .background(ScannerTheme.background.opacity(0.96))
            }
            .safeAreaInset(edge: .bottom, spacing: 8) {
                floatingNavigation {
                    searchFocused = false
                    if reduceMotion {
                        reader.scrollTo("homeTop", anchor: .top)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reader.scrollTo("homeTop", anchor: .top)
                        }
                    }
                }
            }
        }
        .tint(ScannerTheme.accent)
        .foregroundStyle(ScannerTheme.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("المستندات")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.title")
                Spacer()
                Menu {
                    Button("مكتبة المستندات", systemImage: "folder") { path.append(.library) }
                    Button("استيراد صور", systemImage: "photo.on.rectangle") { beginCapture(.photos) }
                    Button("إعدادات التطبيق", systemImage: "gearshape") { showSettings = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .scannerGlass(in: Circle(), interactive: true)
                }
                .accessibilityLabel("خيارات المستندات")
                .accessibilityIdentifier("home.more")
            }
            searchField
            scopePicker
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ScannerTheme.secondary)
                .accessibilityHidden(true)
            TextField("ابحث بالاسم أو بالنص المستخرج", text: $libraryVM.searchText)
                .font(.subheadline)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("البحث في المستندات والنصوص")
                .accessibilityIdentifier("home.search")
            if !libraryVM.searchText.isEmpty {
                Button {
                    libraryVM.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ScannerTheme.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("مسح البحث")
                .accessibilityIdentifier("home.clearSearch")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, libraryVM.searchText.isEmpty ? 16 : 0)
        .frame(minHeight: 44)
        .padding(.vertical, 2)
        .background(ScannerTheme.surface.opacity(0.7), in: Capsule())
        .overlay { Capsule().stroke(ScannerTheme.border.opacity(0.5), lineWidth: 0.5) }
    }

    private var scopePicker: some View {
        ScrollView(.horizontal) {
            ScannerGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(HomeScope.allCases) { option in
                        Button { scope = option } label: {
                            Text(option.rawValue)
                                .font(.caption.weight(scope == option ? .semibold : .regular))
                                .foregroundStyle(scope == option ? ScannerTheme.accent : ScannerTheme.secondary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(scope == option ? ScannerTheme.selected : .clear, in: Capsule())
                        }
                        .buttonStyle(HomePressStyle())
                        .accessibilityAddTraits(scope == option ? [.isSelected] : [])
                        .accessibilityIdentifier("home.scope.\(option.id)")
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.leading)
    }

    private var quickActions: some View {
        ScannerGlassGroup(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                     count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 16) {
                quickAction("مسح مستند", icon: "doc.viewfinder", id: "home.scan") { beginCapture(.camera) }
                quickAction("استيراد صور", icon: "photo.on.rectangle.angled", id: "home.import") { beginCapture(.photos) }
                quickAction("المكتبة", icon: "folder", id: "home.library") { path.append(.library) }
                quickAction("الإعدادات", icon: "slider.horizontal.3", id: "home.settings") { showSettings = true }
            }
        }
        .padding(.horizontal, 20)
    }

    private func quickAction(_ title: String, icon: String, id: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(ScannerTheme.accent)
                    .frame(width: 56, height: 56)
                    .scannerGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(ScannerTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle())
        .accessibilityIdentifier(id)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("الأخيرة").font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { path.append(.library) } label: {
                    Label("عرض الكل", systemImage: "chevron.forward")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(matchingDocuments.prefix(5))) { document in
                        NavigationLink(value: HomeRoute.document(document.id)) {
                            HomeDocumentCard(document: document)
                        }
                        .buttonStyle(HomePressStyle())
                        .accessibilityIdentifier("home.recent.\(document.id)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.leading)
        }
    }

    private var filesSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("كل الملفات").font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    Picker("ترتيب المستندات", selection: $sort) {
                        ForEach(HomeSort.allCases) { option in Text(option.rawValue).tag(option) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("ترتيب المستندات")
                .accessibilityValue(sort.rawValue)
                .accessibilityIdentifier("home.sort")
            }
            ForEach(sortedDocuments) { document in
                NavigationLink(value: HomeRoute.document(document.id)) {
                    HomeDocumentListRow(document: document)
                }
                .buttonStyle(HomePressStyle())
                .accessibilityIdentifier("home.file.\(document.id)")
                Divider().overlay(ScannerTheme.border.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func floatingNavigation(home: @escaping () -> Void) -> some View {
        if typeSize.isAccessibilitySize {
            accessibleNavigation(home: home)
        } else {
            regularFloatingNavigation(home: home)
        }
    }

    private func accessibleNavigation(home: @escaping () -> Void) -> some View {
        ScannerGlassGroup(spacing: 12) {
            VStack(spacing: 12) {
                Button { beginCapture(.camera) } label: {
                    Label("مسح مستند", systemImage: "viewfinder")
                        .font(.headline)
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .scannerGlass(in: RoundedRectangle(cornerRadius: 24), interactive: true)
                }
                .accessibilityIdentifier("home.nav.scan")
                HStack(spacing: 12) {
                    Button(action: home) { Label("الرئيسية", systemImage: "house.fill") }
                        .accessibilityIdentifier("home.nav.home")
                    Spacer(minLength: 0)
                    Menu {
                        Button("المكتبة", systemImage: "folder") { path.append(.library) }
                        Button("استيراد صور", systemImage: "photo.on.rectangle") { beginCapture(.photos) }
                        Button("الإعدادات", systemImage: "gearshape") { showSettings = true }
                    } label: {
                        Label("الانتقال", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("home.nav.destinations")
                }
                .font(.headline)
                .padding(12)
                .frame(minHeight: 44)
                .scannerGlass(in: RoundedRectangle(cornerRadius: 24))
            }
            .fixedSize(horizontal: false, vertical: true)
            .buttonStyle(HomePressStyle())
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func regularFloatingNavigation(home: @escaping () -> Void) -> some View {
        ScannerGlassGroup(spacing: 12) {
            ZStack {
                HStack(spacing: 0) {
                    Button(action: home) { navLabel("الرئيسية", icon: "house.fill", selected: true) }
                        .accessibilityAddTraits(.isSelected)
                        .accessibilityIdentifier("home.nav.home")
                    Button { path.append(.library) } label: { navLabel("المكتبة", icon: "folder") }
                        .accessibilityIdentifier("home.nav.library")
                    Color.clear.frame(width: 76, height: 48)
                        .accessibilityHidden(true)
                    Button { beginCapture(.photos) } label: { navLabel("استيراد", icon: "photo.on.rectangle") }
                        .accessibilityIdentifier("home.nav.import")
                    Button { showSettings = true } label: { navLabel("الإعدادات", icon: "gearshape") }
                        .accessibilityIdentifier("home.nav.settings")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
                .frame(minHeight: 68)
                .scannerGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Sibling glass surfaces share a container; never nest glass inside glass.
                Button { beginCapture(.camera) } label: {
                    HomeScanButtonLabel()
                }
                .accessibilityLabel("مسح مستند جديد")
                .accessibilityIdentifier("home.nav.scan")
                .offset(y: -14)
            }
            .buttonStyle(HomePressStyle())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("التنقل الرئيسي")
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func navLabel(_ title: String, icon: String, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(selected ? ScannerTheme.accent : ScannerTheme.secondary)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("ابدأ أول مستند", systemImage: "doc.text.viewfinder")
        } description: {
            Text("امسح مستنداً بالكاميرا أو استورد صوراً. ستظهر ملفاتك هنا بعد حفظها في المكتبة.")
        } actions: {
            Button("مسح مستند") { beginCapture(.camera) }
                .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("home.empty")
        .padding(.horizontal, 20)
    }

    private var noResults: some View {
        ContentUnavailableView {
            Label("لا توجد مستندات مطابقة", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("جرّب اسماً آخر أو غيّر التصفية.")
        } actions: {
            Button("عرض جميع المستندات") {
                libraryVM.searchText = ""
                scope = .all
            }
        }
        .accessibilityIdentifier("home.noResults")
    }

    private var footer: some View {
        Text("Powered by Tertiary Infotech Academy Pte Ltd")
            .font(.caption2)
            .foregroundStyle(ScannerTheme.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .environment(\.layoutDirection, .leftToRight)
    }

    private func beginCapture(_ source: CaptureSource) {
        searchFocused = false
        capture = source
    }

    private func captureCompleted(_ images: [UIImage]) {
        if !images.isEmpty {
            scannerVM.beginNewDocument(with: images)
            pendingEditor = true
        }
        capture = nil
    }

    private func captureDismissed() {
        // Present only after the camera/picker has dismissed, not two covers in one update.
        guard pendingEditor else { return }
        pendingEditor = false
        showEditor = true
    }
}
