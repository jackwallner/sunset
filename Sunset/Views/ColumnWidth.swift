import SwiftUI

/// Content widths for regular-width screens (iPad, Split View, Stage-like
/// resizing). Phones and narrow windows never reach these limits, so their
/// layouts are untouched.
enum ColumnWidth {
    /// One reading column: Settings, a single-column Today or show.
    static let reading: CGFloat = 640
    /// Two columns side by side, and the Outlook's day-card grid.
    static let wide: CGFloat = 1240
    /// A container this wide lays Today and the show detail out in two
    /// columns.
    static let twoColumnFrom: CGFloat = 900

    /// Side margin that centres content of at most `maxWidth` in `width`.
    static func margin(width: CGFloat, maxWidth: CGFloat) -> CGFloat {
        max(0, ((width - maxWidth) / 2).rounded(.down))
    }

    /// Day cards per row in the Outlook.
    static func outlookColumns(width: CGFloat) -> Int {
        width >= 1100 ? 3 : width >= 720 ? 2 : 1
    }
}

extension View {
    /// Centres a scroll view's content in a column of at most `maxWidth`,
    /// leaving the scroll indicator and the sky at the container's edges.
    func readableColumn(_ maxWidth: CGFloat = ColumnWidth.reading) -> some View {
        modifier(ReadableColumn(maxWidth: maxWidth))
    }

    /// The container's width, kept current.
    func trackWidth(_ width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width.wrappedValue = $0 }
    }
}

private struct ReadableColumn: ViewModifier {
    let maxWidth: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, ColumnWidth.margin(width: width, maxWidth: maxWidth), for: .scrollContent)
            .trackWidth($width)
    }
}
