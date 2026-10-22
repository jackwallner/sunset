import SwiftUI

/// Pane frames for the unfolded iPhone Duo: Today and the tab bar on the
/// leading side of the fold, the week's Outlook on the trailing side, so no
/// card straddles the crease. `nil` keeps the single phone column (every
/// ordinary iPhone, the folded Duo, and any width too narrow for two panes).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the phone layout of Today and Outlook.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }

    static func make(_ geometry: PaneGeometry, isRegularWidth: Bool) -> UnfoldedSplit? {
        make(width: geometry.width, isRegularWidth: isRegularWidth, fold: geometry.fold)
    }
}

/// A container's width and its vertical fold, measured together.
struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?
}

extension GeometryProxy {
    var paneGeometry: PaneGeometry {
        PaneGeometry(width: size.width, fold: verticalFold())
    }

    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

extension View {
    /// Keeps a one-column screen (onboarding, the full-screen paywall) in the
    /// leading pane when unfolded, instead of across the fold. Apply it before
    /// the screen's sky so the sky still fills the display.
    func leadingPaneColumn() -> some View {
        modifier(LeadingPaneColumn())
    }
}

private struct LeadingPaneColumn: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var geometry = PaneGeometry()

    func body(content: Content) -> some View {
        let split = UnfoldedSplit.make(geometry, isRegularWidth: horizontalSizeClass == .regular)
        content
            .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
            .frame(maxWidth: split?.primaryWidth ?? .infinity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: PaneGeometry.self) { $0.paneGeometry } action: { geometry = $0 }
    }
}
