import SwiftUI

struct ProfileAvatar: View {
    let profile: SSHProfile
    var size: CGFloat = 32

    private var initials: String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.count >= 2,
           let a = words[0].first,
           let b = words[1].first {
            return String([a, b]).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    static func color(for profile: SSHProfile) -> Color {
        let palette: [Color] = [
            Color(red: 0.30, green: 0.62, blue: 0.95),  // blue
            Color(red: 0.40, green: 0.78, blue: 0.55),  // green
            Color(red: 0.95, green: 0.65, blue: 0.30),  // orange
            Color(red: 0.85, green: 0.46, blue: 0.72),  // pink
            Color(red: 0.62, green: 0.46, blue: 0.85),  // purple
            Color(red: 0.92, green: 0.45, blue: 0.45),  // red
            Color(red: 0.30, green: 0.72, blue: 0.78),  // teal
            Color(red: 0.46, green: 0.55, blue: 0.85),  // indigo
            Color(red: 0.50, green: 0.78, blue: 0.70),  // mint
            Color(red: 0.30, green: 0.70, blue: 0.85)   // cyan
        ]
        var hasher = Hasher()
        hasher.combine(profile.id)
        let value = abs(hasher.finalize())
        return palette[value % palette.count]
    }

    var body: some View {
        let radius = size * 0.28
        let avatarColor = ProfileAvatar.color(for: profile)
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [avatarColor.opacity(0.95), avatarColor.opacity(0.70)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                }

            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
        }
    }
}

extension Date {
    func compactRelativeString(now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(self)
        if interval < 60 { return "now" }
        let minute = 60.0
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day
        let month = 30 * day
        let year = 365 * day

        switch interval {
        case ..<hour:    return "\(Int(interval / minute))m"
        case ..<day:     return "\(Int(interval / hour))h"
        case ..<week:    return "\(Int(interval / day))d"
        case ..<month:   return "\(Int(interval / week))w"
        case ..<year:    return "\(Int(interval / month))mo"
        default:         return "\(Int(interval / year))y"
        }
    }
}
