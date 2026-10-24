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

/// Where a pane's content ends. The leading pane's content ends `gap` above
/// the floating tab bar's safe-area edge, and a bottom scroll content margin
/// of `gap` lets the last row scroll up to that line. The trailing pane has
/// no bar: its content runs to the display edge, as on a phone, but still
/// in whole rows. Folded, nothing is hidden and the phone layout is untouched.
struct PaneClearance: Equatable, Sendable {
    /// Masked out from the bottom: the bar's inset plus the gap.
    var hidden: CGFloat
    /// Bottom scroll content margin; `nil` keeps the system's.
    var contentMargin: CGFloat?

    static let gap: CGFloat = 12

    static func make(isSplit: Bool, hasBar: Bool = true, barInset: CGFloat) -> PaneClearance {
        guard isSplit, hasBar else { return PaneClearance(hidden: 0, contentMargin: nil) }
        return PaneClearance(hidden: max(barInset, 0) + gap, contentMargin: gap)
    }
}

/// Where a pane's content stops above its bar. A block (a card, a list
/// section, a caption) the clearance line would slice ends early below its
/// last whole row, with rounded bottom corners as if it ended there, or
/// hides whole when not one row fits. So a pane never shows half a row.
struct PaneCut: Equatable, Sendable {
    /// In the same space as the blocks' frames.
    var y: CGFloat
    /// The block that ends early at `y`, whose corners the cut rounds.
    var closes: Closing?

    struct Closing: Equatable, Sendable {
        var minX: CGFloat
        var maxX: CGFloat
        var radius: CGFloat
    }

    /// A block's corner radius, and the space it keeps below its last row.
    struct Style: Equatable, Sendable {
        var radius: CGFloat
        var padding: CGFloat

        /// 12 rather than the card's 18 pt padding: rows sit 14 pt apart, so
        /// a fuller margin would show the top of the next row.
        static let card = Style(radius: Theme.cardRadius, padding: 12)
        /// The trailing pane's day cards, whose rows sit 10 pt apart.
        static let tightCard = Style(radius: Theme.cardRadius, padding: 8)
        /// An inset grouped List section: rows measure their whole cell.
        static let groupedList = Style(radius: 26, padding: 0)
    }

    /// One measured view: a block's frame or one of its rows.
    struct Part: Equatable, Sendable {
        var block: String
        var frame: CGRect
        var isRow: Bool
        var style: Style
    }

    struct Block: Equatable, Sendable {
        var frame: CGRect
        /// Where the block can end early: below each whole row.
        var breaks: [CGFloat]
        var radius: CGFloat
    }

    static func blocks(from parts: some Sequence<Part>) -> [Block] {
        Dictionary(grouping: parts, by: \.block).values.map { parts in
            Block(
                frame: parts.dropFirst().reduce(parts[0].frame) { $0.union($1.frame) },
                breaks: parts.filter(\.isRow).map { $0.frame.maxY + $0.style.padding },
                radius: parts[0].style.radius
            )
        }
    }

    static func make(line: CGFloat, blocks: some Sequence<Block>) -> PaneCut {
        var cut = PaneCut(y: line, closes: nil)
        for block in blocks where block.frame.minY < line - 0.5 && block.frame.maxY > line + 0.5 {
            let end = block.breaks.filter { $0 > block.frame.minY && $0 <= line }.max()
            let candidate = end.map {
                PaneCut(y: $0, closes: Closing(minX: block.frame.minX, maxX: block.frame.maxX, radius: block.radius))
            } ?? PaneCut(y: block.frame.minY, closes: nil)
            if candidate.y < cut.y { cut = candidate }
        }
        return cut
    }
}

/// Today in the unfolded leading pane opens on whole cards: the hero sky
/// takes the height the summary and factor cards leave above the bar line,
/// so the factor card ends there instead of being cut to its first row.
enum PaneFill {
    /// - Parameters:
    ///   - viewport: the scroll view's height inside its safe area.
    ///   - spacing: padding and stack spacing around the hero and cards.
    ///   - cards: the heights of the cards under the hero.
    /// - Returns: `nil` until every height is measured.
    static func heroHeight(viewport: CGFloat, spacing: CGFloat, cards: [CGFloat], minimum: CGFloat) -> CGFloat? {
        guard viewport > 0, !cards.isEmpty, cards.allSatisfy({ $0 > 0 }) else { return nil }
        let room = viewport - PaneClearance.gap - spacing - cards.reduce(0, +)
        return max(minimum, room.rounded(.down))
    }
}

/// The trailing pane meets the display edge, where iOS 27.1 draws the status
/// bar as a vertical column (clock over the connectivity ring) and reserves
/// its width as trailing safe area down the whole pane. Content runs under
/// that column, so the pane's margins match, and starts below the clock.
enum StatusColumn {
    /// The clock, ring and their backing end 112 pt down the display; the
    /// Outlook's first card sits 83 pt down under its large title. Measured
    /// from the iOS 27.1 iPhone Duo inner display.
    static let clockClearance: CGFloat = 36

    /// Top padding that starts a screen's first card below the clock.
    static func clockPadding(columnWidth: CGFloat) -> CGFloat {
        columnWidth > 0 ? clockClearance : 0
    }
}

/// The blocks one pane's scroll view reports, read by its mask.
@MainActor @Observable
final class PaneBlocks {
    var parts: [UUID: PaneCut.Part] = [:]
}

extension EnvironmentValues {
    /// True in the unfolded leading pane, above the floating tab bar.
    @Entry var isLeadingPane = false
    /// True in the unfolded trailing pane (the Outlook and its pushes).
    @Entry var isTrailingPane = false
    /// The pane's block frames. `nil` folded, so the phone layout does no
    /// bookkeeping while it scrolls.
    @Entry var paneBlocks: PaneBlocks? = nil
    /// The card a `paneRow()` belongs to.
    @Entry var paneBlockID: String? = nil
    /// The trailing pane's status column width, under which its content is
    /// laid out (`fillsTrailingPane()`); 0 elsewhere.
    @Entry var statusColumnWidth: CGFloat = 0
}

extension View {
    /// In an unfolded pane, ends a scroll view's content just above the
    /// leading pane's floating tab bar, or at the trailing pane's display
    /// edge, without slicing a row (see `PaneCut`). Blocks must
    /// be tagged (`paneCard()`, `paneListRow`) or the line cuts through them.
    /// Folded the mask is fully open. Apply it to the scroll view, before
    /// the screen's sky.
    func clearsPaneBottom() -> some View {
        modifier(PaneBottomClearance())
    }

    /// A card (or caption) the pane cut ends below a whole `paneRow()` or
    /// hides whole.
    func paneCard(_ style: PaneCut.Style = .card) -> some View {
        modifier(PaneCardBlock(style: style))
    }

    /// A row of the enclosing `paneCard()`: the card can end below it.
    func paneRow(_ style: PaneCut.Style = .card) -> some View {
        modifier(PanePartReporter(block: nil, isRow: true, style: style))
    }

    /// A row of an inset grouped List section, measured through its row
    /// background, which fills the cell.
    func paneListRow(_ section: String) -> some View {
        listRowBackground(
            Theme.row.modifier(PanePartReporter(block: section, isRow: true, style: .groupedList))
        )
    }

    /// A List section's header or footer, cut with the section's rows.
    func paneListPart(_ section: String) -> some View {
        modifier(PanePartReporter(block: section, isRow: false, style: .groupedList))
    }

    /// In the unfolded trailing pane, lays the content out under the status
    /// column at the display edge, so cards fill the pane with even margins
    /// (see `StatusColumn`). Elsewhere it does nothing.
    func fillsTrailingPane() -> some View {
        modifier(TrailingPaneFill())
    }

    /// Inside `fillsTrailingPane()`, starts the content below the status
    /// column's clock. Leave it off where the top right corner is empty sky.
    func clearsStatusClock() -> some View {
        modifier(StatusClockClearance())
    }

    /// Keeps the phone's horizontal tab bar in the unfolded leading pane.
    /// iOS 27.1 otherwise draws it as a bottom capsule on some screens and a
    /// vertical rail beside the fold on others. Folded, the system default.
    /// Apply it to each leading tab only: set anywhere in the trailing pane
    /// (its stack or its screens), the whole app was laid out 42 pt in from
    /// both display edges, between black strips. The trailing pane's pushes
    /// use `PaneBackHeader` instead.
    @ViewBuilder
    func horizontalBarsInPane(_ isSplit: Bool) -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(isSplit ? .disabled : .automatic)
        } else {
            self
        }
    }
}

private struct PaneBottomClearance: ViewModifier {
    @Environment(\.isLeadingPane) private var isLeadingPane
    @Environment(\.isTrailingPane) private var isTrailingPane
    @State private var barInset: CGFloat = 0
    @State private var blocks = PaneBlocks()

    func body(content: Content) -> some View {
        let isSplit = isLeadingPane || isTrailingPane
        let clearance = PaneClearance.make(isSplit: isSplit, hasBar: isLeadingPane, barInset: barInset)
        content
            .environment(\.paneBlocks, isSplit ? blocks : nil)
            .contentMargins(.bottom, clearance.contentMargin, for: .scrollContent)
            .bottomScrollEdgeEffectHidden(isSplit)
            .mask {
                PaneCutMask(blocks: blocks, hidden: clearance.hidden, isSplit: isSplit)
                    .ignoresSafeArea()
            }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { barInset = $0 }
            .onChange(of: isSplit) { blocks.parts = [:] }
    }
}

private struct TrailingPaneFill: ViewModifier {
    @Environment(\.isTrailingPane) private var isTrailingPane
    @State private var columnWidth: CGFloat = 0

    func body(content: Content) -> some View {
        let width = isTrailingPane ? columnWidth : 0
        content
            .environment(\.statusColumnWidth, width)
            .ignoresSafeArea(.container, edges: width > 0 ? .trailing : [])
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: { measured in
                // Keep the width once seen: laid out under the column, the
                // view may no longer report it.
                if measured > 0 || columnWidth == 0 { columnWidth = measured }
            }
    }
}

private struct StatusClockClearance: ViewModifier {
    @Environment(\.statusColumnWidth) private var columnWidth

    func body(content: Content) -> some View {
        content.padding(.top, StatusColumn.clockPadding(columnWidth: columnWidth))
    }
}

private struct PaneCutMask: View {
    let blocks: PaneBlocks
    let hidden: CGFloat
    let isSplit: Bool

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let cut = isSplit
                ? PaneCut.make(line: frame.maxY - hidden, blocks: PaneCut.blocks(from: blocks.parts.values))
                : PaneCut(y: frame.maxY, closes: nil)
            let y = min(max(cut.y - frame.minY, 0), frame.height)
            let radius = cut.closes.map { min($0.radius, y / 2) } ?? 0
            // Two overlapping shapes rather than one path, so no seam shows
            // where the straight part meets the rounded card bottom.
            ZStack(alignment: .topLeading) {
                Rectangle().frame(width: frame.width, height: y - radius)
                if let closes = cut.closes, radius > 0 {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: radius,
                        bottomTrailingRadius: radius,
                        style: .continuous
                    )
                    .frame(width: closes.maxX - closes.minX, height: radius * 2)
                    .offset(x: closes.minX - frame.minX, y: y - radius * 2)
                }
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        }
    }
}

private struct PaneCardBlock: ViewModifier {
    let style: PaneCut.Style
    @State private var id = UUID().uuidString

    func body(content: Content) -> some View {
        content
            .environment(\.paneBlockID, id)
            .modifier(PanePartReporter(block: id, isRow: false, style: style))
    }
}

private struct PanePartReporter: ViewModifier {
    /// `nil` joins the enclosing `paneCard()`.
    let block: String?
    let isRow: Bool
    let style: PaneCut.Style
    @Environment(\.paneBlocks) private var paneBlocks
    @Environment(\.paneBlockID) private var enclosingBlock
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                guard let paneBlocks, let name = block ?? enclosingBlock else { return }
                let part = PaneCut.Part(block: name, frame: frame, isRow: isRow, style: style)
                if paneBlocks.parts[id] != part { paneBlocks.parts[id] = part }
            }
            .onDisappear { paneBlocks?.parts[id] = nil }
    }
}

private extension View {
    @ViewBuilder
    func bottomScrollEdgeEffectHidden(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .bottom)
        } else {
            self
        }
    }
}
