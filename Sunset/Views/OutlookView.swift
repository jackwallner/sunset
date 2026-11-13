import SwiftUI

/// The week ahead. Today and tomorrow are free; the rest is Sun+, shown
/// blurred so the free tier can see what it is missing.
struct OutlookView: View {
    @EnvironmentObject private var forecastStore: ForecastStore
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var store: StoreService
    @Environment(\.isTrailingPane) private var isTrailingPane
    @State private var showPaywall = false
    @State private var viewWidth: CGFloat = 0

    static let freeDays = 2

    private var columns: Int { ColumnWidth.outlookColumns(width: viewWidth) }

    var body: some View {
        ScrollView {
            // In the trailing pane, which starts below the status clock, the
            // week packs a little tighter so its last card ends whole.
            VStack(spacing: isTrailingPane ? 8 : 12) {
                if let forecast = forecastStore.forecast {
                    let days = Array(forecast.upcomingDays().prefix(7))
                    DayGrid(days: Array(days.prefix(store.isPro ? days.count : Self.freeDays)), columns: columns, spacing: 12) { day in
                        DayCard(day: day, forecast: forecast, watched: settings.watched)
                    }
                    if !store.isPro, days.count > Self.freeDays {
                        lockedWeek(Array(days.dropFirst(Self.freeDays)), forecast: forecast)
                    }
                } else {
                    Text("The outlook appears once the forecast has loaded.")
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .clearsStatusClock()
        }
        .clearsPaneBottom()
        .contentMargins(.horizontal, ColumnWidth.margin(width: viewWidth, maxWidth: ColumnWidth.wide), for: .scrollContent)
        .trackWidth($viewWidth)
        .fillsTrailingPane()
        .background {
            SkyBackdrop(score: forecastStore.nextShow?.score.total ?? 60, event: forecastStore.nextShow?.event ?? .sunset, horizon: 0.14)
        }
        .navigationTitle("Outlook")
        .sheet(isPresented: $showPaywall) { PaywallView(source: "outlook").pageSheet() }
    }

    /// The real days, blurred past reading, under one unlock card.
    private func lockedWeek(_ days: [SunsetDay], forecast: SunsetForecast) -> some View {
        // Three days are enough to show what is behind the lock without a
        // long scroll of blur under the card.
        DayGrid(days: Array(days.prefix(3)), columns: columns, spacing: 12) { day in
            DayCard(day: day, forecast: forecast, watched: settings.watched, isLinked: false)
        }
        .blur(radius: 9, opaque: false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .overlay(alignment: .top) {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.ember)
                Text("The rest of the week")
                    .font(.title3.weight(.semibold))
                Text("Every sunrise and sunset score through \(lastDayName(days, forecast: forecast)), plus storm, rainbow and fog alerts.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                Button("Unlock with Sun+") { showPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .glass(tint: 0.3)
            .frame(maxWidth: 440)
            .padding(.top, 40)
            .padding(.horizontal, 8)
        }
    }

    private func lastDayName(_ days: [SunsetDay], forecast: SunsetForecast) -> String {
        guard let last = days.last else { return "the week" }
        return SunsetFormat.weekday(last.sunset.time, zone: forecast.timeZone)
    }
}

/// Day cards in rows of `columns`; one column is the phone's plain stack.
/// A `Grid` keeps the cards of a row the same height.
private struct DayGrid<Item: View>: View {
    let days: [SunsetDay]
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let card: (SunsetDay) -> Item

    var body: some View {
        if columns <= 1 {
            VStack(spacing: spacing) {
                ForEach(days) { card($0) }
            }
        } else {
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { card($0) }
                        ForEach(0..<(columns - row.count), id: \.self) { _ in Color.clear }
                    }
                }
            }
        }
    }

    private var rows: [[SunsetDay]] {
        stride(from: 0, to: days.count, by: columns).map { Array(days[$0..<min($0 + columns, days.count)]) }
    }
}

private struct DayCard: View {
    let day: SunsetDay
    let forecast: SunsetForecast
    let watched: Set<SunEvent>
    var isLinked = true
    @Environment(\.isTrailingPane) private var isTrailingPane
    @Environment(\.paneDetail) private var paneDetail

    var body: some View {
        let zone = forecast.timeZone
        let shows = SunEvent.allCases.filter(watched.contains).map(day.show)
        let events = forecast.skyEvents(on: day)
        let cut: PaneCut.Style = isTrailingPane ? .tightCard : .card
        VStack(alignment: .leading, spacing: isTrailingPane ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(SunsetFormat.dayLabel(day.sunset.time, zone: zone))
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(SunsetFormat.monthDay(day.sunset.time, zone: zone))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(shows) { show in
                if isLinked, let paneDetail {
                    // Unfolded, the show opens in the leading pane and the
                    // week stays here, its picked row lit.
                    Button { paneDetail.wrappedValue = show } label: {
                        ShowRow(show: show, zone: zone)
                            .background {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(paneDetail.wrappedValue?.id == show.id ? 0.16 : 0))
                                    .padding(-6)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(paneDetail.wrappedValue?.id == show.id ? .isSelected : [])
                    .paneRow(cut)
                } else if isLinked {
                    NavigationLink {
                        ShowDetailView(show: show, zone: zone, placeName: forecast.placeName)
                    } label: {
                        ShowRow(show: show, zone: zone)
                    }
                    .buttonStyle(.plain)
                    .paneRow(cut)
                } else {
                    ShowRow(show: show, zone: zone, showsChevron: false)
                        .paneRow(cut)
                }
            }
            if !events.isEmpty {
                HStack(spacing: 14) {
                    ForEach(events) { event in
                        Label("\(event.kind.title) \(SunsetFormat.time(event.start, zone: zone))", systemImage: event.kind.symbol)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .paneRow(cut)
            }
        }
        .padding(18)
        // Fills its grid row, so a shorter card matches its neighbour.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { DaySky(show: lead) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .paneCard(cut)
    }

    /// The show that colours the card: the sunset when it is watched,
    /// otherwise the sunrise.
    private var lead: SunShow {
        watched.contains(.sunset) || watched.isEmpty ? day.sunset : day.sunrise
    }
}

/// A day's own forecast sky, darkened on the side the text sits on.
private struct DaySky: View {
    let show: SunShow

    var body: some View {
        ZStack {
            LinearGradient(
                colors: Theme.readableSkyRGB(score: show.score.total, event: show.event).map(\.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [.black.opacity(0.24), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct ShowDetailView: View {
    let show: SunShow
    let zone: TimeZone
    let placeName: String?
    @Environment(\.isLeadingPane) private var isLeadingPane
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Unfolded: the viewport and the summary card's height.
    @State private var paneViewport: CGFloat = 0
    @State private var summaryHeight: CGFloat = 0
    @State private var viewWidth: CGFloat = 0

    /// Two columns on a wide screen: the hero and summary, then the breakdown.
    private var isTwoColumn: Bool { viewWidth >= ColumnWidth.twoColumnFrom }

    var body: some View {
        let heroHeight = paneHeroHeight
        ScrollViewReader { proxy in
            ScrollView {
                if isTwoColumn {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 16) {
                            heroBlock(heroHeight)
                            summaryCard
                        }
                        VStack(spacing: 16) {
                            factorsCard
                            cloudCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                } else {
                    VStack(spacing: 16) {
                        heroBlock(heroHeight)
                        summaryCard
                        factorsCard
                        cloudCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .clearsPaneBottom()
            .contentMargins(.horizontal, ColumnWidth.margin(width: viewWidth, maxWidth: isTwoColumn ? ColumnWidth.wide : ColumnWidth.reading), for: .scrollContent)
            .trackWidth($viewWidth)
            // The size is already inside the nav and tab bars; the proxy
            // still reports their insets, so subtracting them counted the
            // bars twice (logged 2026-10-23: size 504, insets 82 and 83).
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paneViewport = $0 }
            #if DEBUG
            .task {
                // Store capture: open on the factors and cloud cover.
                guard ScreenshotRouter.shared.scene == "detail" else { return }
                try? await Task.sleep(for: .milliseconds(500))
                proxy.scrollTo("factors", anchor: .top)
            }
            #endif
        }
        .background { SkyBackdrop(score: show.score.total, event: show.event, horizon: dynamicTypeSize.isAccessibilitySize ? 0.62 : 0.42) }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(SunsetFormat.monthDay(show.time, zone: zone))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heroBlock(_ heroHeight: CGFloat?) -> some View {
        SkyHero(show: show, zone: zone, title: SunsetFormat.headline(show, zone: zone), placeName: placeName)
            .modifier(HeroFrame { heroHeight ?? min(max(240, $0 * (isTwoColumn ? 0.46 : 0.34)), isTwoColumn ? 600 : 420) })
            .padding(.bottom, 12)
    }

    private var summaryCard: some View {
        Card {
            Text(show.score.summary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                detail("Best light", "\(SunsetFormat.time(show.bestWindowStart, zone: zone)) to \(SunsetFormat.time(show.bestWindowEnd, zone: zone))")
                Spacer()
                detail("Rain", "\(show.score.rainChance)%")
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { summaryHeight = $0 }
    }

    private var factorsCard: some View {
        Card {
            ForEach(show.score.factors) { factor in
                FactorRow(factor: factor, tone: Theme.tone(score: show.score.total))
                    .paneRow()
            }
        }
        .id("factors")
    }

    private var cloudCard: some View {
        Card {
            Text("Cloud cover at \(show.event.title.lowercased())").font(.headline)
            cloudRow("High", show.conditions.cloudHigh)
            cloudRow("Mid", show.conditions.cloudMid)
            cloudRow("Low", show.conditions.cloudLow)
            cloudRow("Low, \(show.event.direction) toward the sun", show.conditions.cloudLowTowardSun)
            Text("Humidity \(Int(show.conditions.humidity))% · Visibility \(visibilityLabel)")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .paneRow()
        }
    }

    /// Unfolded, the factors card is taller than the room under the hero,
    /// so the hero takes that room and the summary ends at the tab bar line
    /// instead of above an empty band (`PaneFill`). Folded, `nil`.
    private var paneHeroHeight: CGFloat? {
        guard isLeadingPane else { return nil }
        // The hero's 12 pt bottom padding, then the 16 pt stack gap.
        return PaneFill.heroHeight(viewport: paneViewport, spacing: 28, cards: [summaryHeight], minimum: 240)
    }

    private var visibilityLabel: String {
        let km = show.conditions.visibility / 1000
        return km >= 10 ? "\(Int(km)) km" : String(format: "%.1f km", km)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private func cloudRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text("\(Int(value))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .paneRow()
    }
}
