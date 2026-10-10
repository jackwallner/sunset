import SwiftUI

/// The forecast sky behind a whole screen. The colours are the score's own
/// sky, so a dull evening looks grey and an epic one burns.
struct SkyBackdrop: View {
    let score: Int
    var event: SunEvent = .sunset
    /// Where the glowing horizon sits, 0 top to 1 bottom.
    var horizon: Double = 0.42

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    stops: Theme.backdropStops(score: score, event: event, horizon: horizon),
                    startPoint: .top,
                    endPoint: .bottom
                )
                // The sun just under the horizon: a warm bloom that grows
                // with the score.
                RadialGradient(
                    colors: [Theme.glow(score: score, event: event).opacity(0.25 + 0.4 * Double(score) / 100), .clear],
                    center: UnitPoint(x: 0.5, y: horizon),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.75
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: score)
        .animation(.easeInOut(duration: 0.6), value: horizon)
        .accessibilityHidden(true)
    }
}

/// The hero: the next sunrise or sunset written straight onto its sky.
struct SkyHero: View {
    let show: SunShow
    let zone: TimeZone
    let title: String
    let placeName: String?
    var height: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let placeName {
                    Label(placeName, systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(show.score.total)")
                    .font(.system(size: 112, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(show.score.grade.rawValue)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .padding(.bottom, 18)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            Label("\(show.event.title) \(SunsetFormat.time(show.time, zone: zone))", systemImage: show.event.symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), score \(show.score.total), \(show.score.grade.rawValue). \(show.event.title) at \(SunsetFormat.time(show.time, zone: zone))")
    }
}

/// A sunrise or sunset as one row: swatch, when, grade, score.
struct ShowRow: View {
    let show: SunShow
    let zone: TimeZone
    var title: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.skyGradient(score: show.score.total, event: show.event))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: show.event.symbol).foregroundStyle(.white.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title ?? show.event.title)
                    .font(.headline)
                Text("\(SunsetFormat.time(show.time, zone: zone)) · \(show.score.grade.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ScoreChip(score: show.score)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A storm, rainbow chance or fog, with when.
struct SkyEventRow: View {
    let event: SkyEvent
    let zone: TimeZone

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.kind.symbol)
                .symbolRenderingMode(event.kind == .fog ? .hierarchical : .multicolor)
                .foregroundStyle(.white)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(event.kind.title).font(.headline)
                Text("\(SunsetFormat.dayLabel(event.start, zone: zone)), \(SunsetFormat.time(event.start, zone: zone))–\(SunsetFormat.time(event.end, zone: zone))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct FactorRow: View {
    let factor: SunsetScore.Factor
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(factor.name).font(.headline)
                Spacer()
                Text("\(factor.value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(tone)
                        .frame(width: max(8, geometry.size.width * CGFloat(factor.value) / 100))
                }
            }
            .frame(height: 8)
            Text(factor.detail)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.name) \(factor.value) out of 100. \(factor.detail)")
    }
}

struct ScoreChip: View {
    let score: SunsetScore

    var body: some View {
        Text("\(score.total)")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.tone(score: score.total), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .accessibilityLabel("Score \(score.total), \(score.grade.rawValue)")
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass()
    }
}

extension View {
    /// Frosted glass over the sky: blurred, a touch darker, with a fine
    /// light edge.
    func glass(cornerRadius: CGFloat = Theme.cardRadius, tint: Double = 0.2) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).fill(.black.opacity(tint)))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }
}

struct PrimaryButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(.white, in: RoundedRectangle(cornerRadius: 17))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct PlusCapsule: View {
    var body: some View {
        Text("Sun+")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.accent, in: Capsule())
    }
}
