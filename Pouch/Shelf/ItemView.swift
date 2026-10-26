import PouchCore
import SwiftUI

/// One thing in the pouch, drawn as what it is: a photo at its real shape,
/// a file as its icon, text as a paper slip, a link as a luggage tag.
struct ItemView: View {
    let item: ShelfItem
    let fileURL: URL?
    let isMissing: Bool
    var isHovered = false
    var isSelected = false
    var isDragging = false
    var isFlashing = false

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Size thumbnails are generated at (and cached under).
    static let thumbnailSize = CGSize(width: 200, height: 200)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            if let caption {
                caption
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(3)
        .overlay {
            // Selected items get stitched around, in the flap's color.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.accent, style: .stitch(width: 1.5))
                .opacity(isSelected ? 1 : 0)
        }
        // Hover lifts the item a little off the canvas.
        .offset(y: isHovered && !reduceMotion ? -1.5 : 0)
        .shadow(color: .black.opacity(isHovered ? 0.16 : 0), radius: 3, y: 2)
        // While dragged out, the item stays behind as a faint ghost.
        .opacity(isDragging ? 0.3 : 1)
        .animation(.pouchHover, value: isHovered)
        .animation(.pouchHover, value: isSelected)
        .animation(.pouchHover, value: isDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .file:
            if let fileURL, !isMissing {
                FileTile(url: fileURL)
                    .overlay { if isFlashing { FlashOverlay() } }
            } else {
                MissingTile()
            }
        case .url(let url):
            LinkTag(url: url)
        case .text(let text):
            NoteSlip(text: text)
        }
    }

    private var caption: Text? {
        switch item.content {
        case .file:
            if item.source == .screenshot, !isMissing {
                // Screenshot names are long and all alike; when it was taken
                // is what tells them apart.
                return Text(Image(systemName: "camera.viewfinder")) + Text(" " + item.addedAt.formatted(date: .omitted, time: .shortened))
            }
            return Text(item.displayName)
        case .url, .text:
            // The tag and the slip carry their own text.
            return nil
        }
    }

    private var accessibilityLabel: String {
        switch item.content {
        case .file: isMissing ? "\(item.displayName), moved or deleted" : item.displayName
        case .url(let url): "Link, \(url.absoluteString)"
        case .text: "Note, \(item.displayName)"
        }
    }
}

// MARK: - Kinds

private struct FileTile: View {
    let url: URL
    @State private var thumbnail: ThumbnailLoader.Thumbnail?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let loader = ThumbnailLoader.shared
        let shown = thumbnail ?? loader.cachedThumbnail(for: url, size: ItemView.thumbnailSize)
        // Images are laid out at their real proportions straight away; other
        // previewable files (PDFs, videos) once their thumbnail exists.
        let aspect = loader.imageAspectRatio(for: url)
            ?? shown.flatMap { $0.isPreview ? $0.image.size.width / max($0.image.size.height, 1) : nil }

        Group {
            if let aspect {
                Group {
                    if let shown, shown.isPreview {
                        Image(nsImage: shown.image).resizable().scaledToFill()
                    } else {
                        Palette.paperRule
                    }
                }
                // Clamped so a panorama or a long receipt doesn't take over.
                .aspectRatio(min(max(aspect, 0.55), 2.4), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
            } else {
                Image(nsImage: (shown ?? loader.icon(for: url)).image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: url) {
            thumbnail = await loader.thumbnail(for: url, size: ItemView.thumbnailSize, scale: displayScale)
        }
    }
}

/// A file that has been deleted or moved somewhere Pouch can't follow.
private struct MissingTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "questionmark")
                .font(.system(size: 11, weight: .semibold))
            Text("Moved or deleted")
                .font(.system(size: 10))
        }
        .foregroundStyle(Palette.inkSecondary)
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.inkSecondary.opacity(0.6), style: .stitch(width: 1)))
    }
}

/// Text, written on a slip of paper with a pinked bottom edge.
private struct NoteSlip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, design: .serif))
            .foregroundStyle(Palette.ink.opacity(0.88))
            .lineSpacing(1.5)
            .lineLimit(7)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .padding(.bottom, 11)
            .background {
                PinkedSlipShape()
                    .fill(Palette.paper)
                    .overlay(alignment: .top) {
                        // A red margin rule, like a notepad.
                        Rectangle().fill(Color(light: 0xE2A79A, dark: 0x7A4C44)).frame(height: 0.75).padding(.top, 4)
                    }
                    .clipShape(PinkedSlipShape())
                    .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
            }
    }
}

/// A link, written on a manila luggage tag.
private struct LinkTag: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(url.host() ?? url.absoluteString)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ink)
            if let path = displayPath {
                Text(path)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(.leading, 18)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            TagShape()
                .fill(Palette.manila, style: FillStyle(eoFill: true))
                .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
        }
    }

    private var displayPath: String? {
        let path = url.path()
        return path.isEmpty || path == "/" ? nil : path
    }
}

/// A camera flash on a screenshot that just arrived.
private struct FlashOverlay: View {
    @State private var opacity = 0.95

    var body: some View {
        Rectangle()
            .fill(.white)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { opacity = 0 }
            }
    }
}
