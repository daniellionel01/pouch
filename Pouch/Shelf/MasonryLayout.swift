import SwiftUI

/// Columns of different-height items, each placed in the shortest column so
/// far. Items keep their own proportions instead of being forced into
/// identical cards.
struct MasonryLayout: Layout {
    var columns = 2
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 200
        let heights = arrange(subviews: subviews, width: width).columnHeights
        return CGSize(width: width, height: max(0, (heights.max() ?? 0) - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = arrange(subviews: subviews, width: bounds.width).placements
        for (subview, frame) in zip(subviews, placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> (placements: [CGRect], columnHeights: [CGFloat]) {
        let columnWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)
        var placements: [CGRect] = []
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            placements.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: heights[column], width: columnWidth, height: height))
            heights[column] += height + spacing
        }
        return (placements, heights)
    }
}
