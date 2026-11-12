import SwiftUI

/// The image is a real on-disk scan thumbnail; missing assets get a file symbol, not sample art.
struct HomeDocumentThumbnail: View {
    let document: ScanDocument
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ScannerTheme.paper)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Image(systemName: "doc.text")
                    .font(.title)
                    .foregroundStyle(ScannerTheme.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ScannerTheme.border.opacity(0.5), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
        .task(id: document.modifiedAt) { thumbnail = document.coverThumbnail() }
    }
}

struct HomeDocumentCard: View {
    let document: ScanDocument
    @ScaledMetric(relativeTo: .body) private var width = 96.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeDocumentThumbnail(document: document)
                .frame(width: width, height: width * 1.32)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            Text(document.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ScannerTheme.ink)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(document.createdAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption)
                .foregroundStyle(ScannerTheme.secondary)
            HomePageCount(count: document.pageCount)
                .font(.caption2)
                .foregroundStyle(ScannerTheme.secondary)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct HomeDocumentListRow: View {
    let document: ScanDocument
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HomeDocumentThumbnail(document: document)
                .frame(width: 44, height: 58)
            VStack(alignment: .leading, spacing: 5) {
                Text(document.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ScannerTheme.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { metadata }
                    VStack(alignment: .leading, spacing: 4) { metadata }
                }
                .font(.caption)
                .foregroundStyle(ScannerTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScannerTheme.secondary)
                .padding(.top, 10)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metadata: some View {
        Text(document.createdAt, format: .dateTime.day().month(.abbreviated).year())
        HomePageCount(count: document.pageCount)
    }
}

/// Locale-aware count without forcing English plural rules onto Arabic.
private struct HomePageCount: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Text("الصفحات:")
            Text(count, format: .number)
        }
    }
}
