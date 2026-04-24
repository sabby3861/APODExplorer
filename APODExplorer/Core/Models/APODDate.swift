//
//  APODDate.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//
//  Value type for an "APOD day". Enforces the valid range at construction
//  (1995-06-16 to today, with a one-day grace window for timezone skew).
//

import Foundation

struct APODDate: Equatable, Hashable, Sendable {
    /// NASA started publishing APOD on 16 June 1995. Dates before that are
    /// invalid because there's no archive for them.
    static let earliest: Date = {
        var components = DateComponents()
        components.year = 1995
        components.month = 6
        components.day = 16
        guard let date = Calendar.posixGMT.date(from: components) else {
            preconditionFailure("1995-06-16 should always be a valid Gregorian date")
        }
        return date
    }()
    
    let startOfDay: Date
    
    init?(date: Date, now: Date = .now) {
        let normalized = Calendar.posixGMT.startOfDay(for: date)
        guard normalized >= Self.earliest else { return nil }
        
        let nowStart = Calendar.posixGMT.startOfDay(for: now)
        // +1 day for the grace window against device clock skew. Failing
        // here (essentially impossible for Gregorian + GMT) is treated as
        // "out of range."
        guard let tomorrow = Calendar.posixGMT.date(byAdding: .day, value: 1, to: nowStart) else {
            return nil
        }
        
        guard normalized <= tomorrow else { return nil }
        self.startOfDay = normalized
    }
    
    // A user picking "Jan 15" in the DatePicker means Jan 15 on their calendar,
    // not Jan 15 UTC. This init converts properly. Without it, a user in
    // UTC+13 picking Jan 15 at 1am local would load Jan 14's picture.
    init?(localDate: Date, timeZone: TimeZone = .current, now: Date = .now) {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone
        let components = localCalendar.dateComponents([.year, .month, .day], from: localDate)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else { return nil }
        
        var gmtComponents = DateComponents()
        gmtComponents.year = year
        gmtComponents.month = month
        gmtComponents.day = day
        
        guard let gmtDate = Calendar.posixGMT.date(from: gmtComponents) else { return nil }
        self.init(date: gmtDate, now: now)
    }
    
    var apiString: String {
        Self.apiFormatter.string(from: startOfDay)
    }
    
    private static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .posixGMT
        formatter.timeZone = .gmt
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension APODDate {
    static func today(now: Date = .now) -> APODDate {
        if let today = APODDate(localDate: now, now: now) {
            return today
        }
        // Unreachable unless the device clock is set before June 1995, in
        // which case every assumption in the app is already wrong.
        preconditionFailure("APODDate.today() could not construct a valid date from current time")
    }
}

extension Calendar {
    static let posixGMT: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()
}
