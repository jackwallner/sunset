import SwiftUI

/// The hero: tonight's sky as a gradient with the score on it.
struct SkyCard: View {
    let day: SunsetDay
    let zone: TimeZone
    let title: String
    let placeName: String?
    var height: CGFloat = 300

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.skyGradient(score: day.score.total))
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
                    }
                }
                .foregroundStyle(.white.opacity(0.92))
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(day.score.total)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(day.score.grade.rawValue)
                        .font(.title.weight(.semibold))
                        .padding(.bottom, 14)
                }
                .foregroundStyle(.white)
                Text("Sunset \(SunsetFormat.time(day.sunset, zone: zone))")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(22)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), sunset score \(day.score.total), \(day.score.grade.rawValue). Sunset at \(SunsetFormat.time(day.sunset, zone: zone))")
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
        Text("Sunset+")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.accent, in: Capsule())
    }
}
