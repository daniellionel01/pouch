import SwiftUI

/// What an empty pouch says: one line, and a hint for first-timers.
struct EmptyNote: View {
    var isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isDropTargeted ? "Drop it" : "Empty")
                .font(.system(size: 16, design: .serif).italic())
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)
            Text("Drag files here. Screenshots are added automatically.")
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
