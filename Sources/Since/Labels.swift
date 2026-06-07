import Foundation

/// Renders a coarse relative label plus the calendar date,
/// e.g. "today (Jun 3)", "yesterday (Jun 2)", "3 weeks ago (May 12)".
/// Dates from another calendar year include the year — "Feb 1" alone
/// is ambiguous once a streak is over a year old.
func sinceLabel(_ lastDone: Date, now: Date) -> String {
    let calendar = Calendar.current
    let sameYear = calendar.component(.year, from: lastDone) == calendar.component(.year, from: now)
    let formatter = sameYear ? monthDay : monthDayYear
    return "\(relative(lastDone, now: now)) (\(formatter.string(from: lastDone)))"
}

// Fixed en_US_POSIX formats so labels match the Go app's "Jan 2" /
// "Jan 2, 2006" wording regardless of system locale.
private let monthDay: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d"
    return f
}()

private let monthDayYear: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM d, yyyy"
    return f
}()

/// Rounds the elapsed time to the largest sensible unit, counting calendar
/// days so "yesterday" means yesterday, not 24 hours ago.
func relative(_ lastDone: Date, now: Date) -> String {
    let days = daysBetween(lastDone, now)
    switch days {
    case ...0:
        return "today"
    case 1:
        return "yesterday"
    case ..<7:
        return "\(days) days ago"
    case ..<30:
        let weeks = days / 7
        return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
    case ..<365:
        let months = days / 30
        return months == 1 ? "1 month ago" : "\(months) months ago"
    default:
        let years = days / 365
        return years == 1 ? "1 year ago" : "\(years) years ago"
    }
}

/// Counts calendar days from a to b in local time.
func daysBetween(_ a: Date, _ b: Date) -> Int {
    let calendar = Calendar.current
    let aDay = calendar.startOfDay(for: a)
    let bDay = calendar.startOfDay(for: b)
    return calendar.dateComponents([.day], from: aDay, to: bDay).day ?? 0
}
