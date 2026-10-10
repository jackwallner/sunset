import SwiftUI

/// The hero: the next sunrise or sunset as a gradient with the score on it.
struct SkyCard: View {
    let show: SunShow
    let zone: TimeZone
    let title: String
    let placeName: String?
    var height: CGFloat = 300

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.skyGradient(score: show.score.total, event: show.event))
            Horizon()
                .fill(Color.black.opacity(0.18))
                .frame(height: 70)
                .frame(maxHeight: .infinity, alignment: .bottom)
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
                .foregroundStyle(.white.opacity(0.92))
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(show.score.total)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(show.score.grade.rawValue)
                        .font(.title.weight(.semibold))
                        .padding(.bottom, 14)
                }
                .foregroundStyle(.white)
                Label("\(show.event.title) \(SunsetFormat.time(show.time, zone: zone))", systemImage: show.event.symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(22)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
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
                .foregroundStyle(Theme.textSecondary)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
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

private struct Horizon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 24))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 10),
            control: CGPoint(x: rect.midX, y: rect.minY - 18)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
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
            .accessibilityLabel("Score \(score.total), \(score.grade.rawValue)")
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

struct PrimaryButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 17))
            .opacity(configuration.isPressed ? 0.9 : 1)
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
