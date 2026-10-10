import SwiftUI
import UIKit

enum Theme {
    /// Every screen sits on a forecast sky, so text is light everywhere.
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let hairline = Color.white.opacity(0.18)
    /// A list row over the sky.
    static let row = Color.black.opacity(0.24)
    /// Text on the white primary button.
    static let ink = Color(red: 0.17, green: 0.10, blue: 0.24)

    static let ember = Color(red: 0.96, green: 0.45, blue: 0.22)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.32)
    static let rose = Color(red: 0.93, green: 0.36, blue: 0.48)
    static let violet = Color(red: 0.42, green: 0.30, blue: 0.62)
    static let dusk = Color(red: 0.20, green: 0.18, blue: 0.38)
    static let mint = Color(red: 0.25, green: 0.78, blue: 0.58)

    static let cardRadius: CGFloat = 22

    static var accent: LinearGradient {
        LinearGradient(colors: [gold, ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The sky a score promises, top to bottom. Dull evenings are grey-blue,
    /// an epic one runs violet through crimson into gold at the horizon.
    static func sky(score: Int, event: SunEvent = .sunset) -> [Color] {
        skyRGB(score: score, event: event).map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
    }

    /// Dawn is cooler than dusk: the same score at sunrise leans pink and
    /// blue at the top instead of violet.
    private static func skyRGB(score: Int, event: SunEvent) -> [RGB] {
        let t = Double(min(100, max(0, score))) / 100
        let stops: [(Double, [RGB])] = [
            (0.0, [.init(0.55, 0.60, 0.68), .init(0.72, 0.74, 0.78), .init(0.86, 0.85, 0.84)]),
            (0.3, [.init(0.42, 0.46, 0.66), .init(0.80, 0.68, 0.64), .init(0.96, 0.84, 0.70)]),
            (0.55, [.init(0.36, 0.30, 0.60), .init(0.93, 0.56, 0.40), .init(1.00, 0.82, 0.45)]),
            (0.8, [.init(0.28, 0.18, 0.50), .init(0.90, 0.36, 0.46), .init(1.00, 0.70, 0.30)]),
            (1.0, [.init(0.20, 0.10, 0.42), .init(0.86, 0.22, 0.44), .init(1.00, 0.62, 0.20)]),
        ]
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for index in 0 ..< stops.count - 1 where t >= stops[index].0 && t <= stops[index + 1].0 {
            lower = stops[index]
            upper = stops[index + 1]
            break
        }
        let span = upper.0 - lower.0
        let w = span == 0 ? 0 : (t - lower.0) / span
        let colors = zip(lower.1, upper.1).map { a, b in
            RGB(a.red + (b.red - a.red) * w,
                a.green + (b.green - a.green) * w,
                a.blue + (b.blue - a.blue) * w)
        }
        guard event == .sunrise else { return colors }
        let dawn = [RGB(0.40, 0.52, 0.80), RGB(0.98, 0.60, 0.62), RGB(1.00, 0.84, 0.60)]
        return zip(colors, dawn).map { c, d in
            RGB(c.red * 0.6 + d.red * 0.4, c.green * 0.6 + d.green * 0.4, c.blue * 0.6 + d.blue * 0.4)
        }
    }

    static func skyGradient(score: Int, event: SunEvent = .sunset) -> LinearGradient {
        LinearGradient(colors: sky(score: score, event: event), startPoint: .top, endPoint: .bottom)
    }

    /// A full-screen sky for a score: night overhead, the forecast colours
    /// down to a glowing horizon at `horizon` (0 top, 1 bottom), then the
    /// same sky reflected in still water below it, dimmer and deepening, so
    /// cards over it read cleanly but still carry the evening's colour.
    static func backdropStops(score: Int, event: SunEvent, horizon: Double) -> [Gradient.Stop] {
        let sky = skyRGB(score: score, event: event)
        let night = RGB(0.06, 0.05, 0.14)
        let deep = RGB(0.05, 0.04, 0.10)
        // Dull skies are pale greys; dim them so white text still reads.
        let dim = 0.62 + 0.30 * Double(min(100, max(0, score))) / 100
        let h = min(0.95, max(0.08, horizon))
        let water = 1 - h
        let stops: [(RGB, Double)] = [
            (night.mixed(with: sky[0], 0.35), 0),
            (sky[0].scaled(dim), h * 0.45),
            (sky[1].scaled(dim), h * 0.82),
            (sky[2].scaled(min(1, dim + 0.08)), h),
            (sky[2].scaled(0.5), h + 0.01),
            (sky[1].scaled(0.42), h + water * 0.22),
            (sky[0].scaled(0.36), h + water * 0.55),
            (deep, 1),
        ]
        return stops.map { .init(color: $0.0.color, location: min(1, $0.1)) }
    }

    static func glow(score: Int, event: SunEvent) -> Color {
        skyRGB(score: score, event: event)[2].color
    }

    /// Solid colour for chips and bars, the warmest stop of the sky.
    static func tone(score: Int) -> Color {
        sky(score: score)[1]
    }
}

struct RGB: Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    func scaled(_ factor: Double) -> RGB {
        RGB(red * factor, green * factor, blue * factor)
    }

    /// `amount` of the way from this colour to `other`.
    func mixed(with other: RGB, _ amount: Double) -> RGB {
        RGB(red + (other.red - red) * amount,
            green + (other.green - green) * amount,
            blue + (other.blue - blue) * amount)
    }
}
