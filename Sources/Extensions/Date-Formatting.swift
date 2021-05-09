import Foundation

extension Date {
    /// A date formatter with a `timeStyle` of `.short` and a `dateStyle` of `.none`.
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    /// A relative date formatter with the default behaviour.
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        return formatter
    }()
    
    /// A string containing the date's time if the date was today, otherwise containing a relative time or date interval.
    var relativeString: String {
        if Calendar.current.isDateInToday(self) {
            return Self.timeFormatter.string(from: self)
        } else {
            return Self.relativeDateFormatter.localizedString(for: self, relativeTo: Date())
        }
    }
}
