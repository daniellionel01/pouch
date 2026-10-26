import PouchCore
import SwiftUI

/// One item on the shelf, drawn as a slightly tilted polaroid.
struct ItemCardView: View {
    let item: ShelfItem
    let fileURL: URL?
    let isMissing: Bool
    var isHovered = false
    var isSelected = false
    var isDragging = false

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let previewHeight: CGFloat = 64
    static let thumbnailSize = CGSize(width: 90, height: previewHeight)

    var body: some View {
        VStack(spacing: 4) {
            preview
                .frame(maxWidth: .infinity)
                .frame(height: Self.previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(caption)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isMissing ? .secondary : .primary)
                .strikethrough(isMissing)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .top)
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isMissing ? 0.4 : 0.95))
                .shadow(color: .black.opacity(isLifted ? 0.22 : 0.12), radius: isLifted ? 6 : 2, y: isLifted ? 3 : 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.accent, lineWidth: isSelected ? 2.5 : 0)
        }
        .rotationEffect(.degrees(isLifted || reduceMotion ? 0 : tilt))
        .scaleEffect(isHovered && !reduceMotion ? 1.05 : 1)
        // While dragged out, the card stays behind as a faint outline.
        .opacity(isDragging ? 0.35 : 1)
        .animation(.pouchHover, value: isHovered)
        .animation(.pouchHover, value: isSelected)
        .animation(.pouchHover, value: isDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var preview: some View {
        switch item.content {
        case .file:
            if let fileURL, !isMissing {
                FileThumbnail(url: fileURL)
            } else {
                MissingPreview()
            }
        case .url(let url):
            LinkPreview(url: url)
        case .text(let text):
            NotePreview(text: text)
        }
    }

    /// Hovered and selected cards straighten up and lift off the shelf.
    private var isLifted: Bool { isHovered || isSelected }

    /// The note preview already shows the text, so don't repeat it.
    private var caption: String {
        if case .text = item.content { return "Note" }
        return item.displayName
    }

    /// A stable tilt between -2.4° and 2.4°, derived from the item's ID so it
    /// doesn't change between launches.
    private var tilt: Double {
        Double(Int(item.id.uuid.0) % 9 - 4) * 0.6
    }

    private var accessibilityLabel: String {
        switch item.content {
        case .file: isMissing ? "\(item.displayName), file not found" : item.displayName
        case .url(let url): "Link, \(url.absoluteString)"
        case .text: "Text, \(item.displayName)"
        }
    }
}

private struct FileThumbnail: View {
    let url: URL
    @State private var thumbnail: ThumbnailLoader.Thumbnail?
    @Environment(\.displayScale) private var displayScale

    private static let size = ItemCardView.thumbnailSize

    var body: some View {
        let shown = thumbnail ?? ThumbnailLoader.shared.cachedThumbnail(for: url, size: Self.size) ?? ThumbnailLoader.shared.icon(for: url)
        Group {
            if shown.isPreview {
                Image(nsImage: shown.image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(nsImage: shown.image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.04))
        .task(id: url) {
            thumbnail = await ThumbnailLoader.shared.thumbnail(for: url, size: Self.size, scale: displayScale)
        }
    }
}

/// A dashed "ghost" for files that have been deleted or can't be found.
private struct MissingPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            VStack(spacing: 2) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 18))
                Text("Wandered off")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct LinkPreview: View {
    let url: URL
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Rectangle().fill(theme.accent.gradient)
            VStack(spacing: 3) {
                Image(systemName: "link")
                    .font(.system(size: 18, weight: .bold))
                Text(url.path().isEmpty || url.path() == "/" ? url.absoluteString : url.path())
                    .font(.system(size: 8, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
            }
            .foregroundStyle(.white)
        }
    }
}

/// Text items look like a little sticky note.
private struct NotePreview: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(.system(size: 8, design: .rounded))
            .foregroundStyle(.primary.opacity(0.8))
            .lineLimit(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(6)
            .background(theme.accent.opacity(0.22))
    }
}
