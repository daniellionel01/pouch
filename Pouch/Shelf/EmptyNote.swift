import SwiftUI

/// What the inside of an empty pouch says. Set like a note in the lining:
/// top-left, a serif line and a plain one.
struct EmptyNote: View {
    var isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isDropTargeted ? "Let go." : "Nothing in here.")
                .font(.system(size: 16, design: .serif).italic())
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)
            Text("Drop files on me. New screenshots find their own way in.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.pouchLand, value: isDropTargeted)
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
