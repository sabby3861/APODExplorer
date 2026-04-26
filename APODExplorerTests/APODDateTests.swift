//
//  APODDateTests.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 21/04/2026.
//

import Testing
import Foundation
@testable import APODExplorer

@Suite("APODDate: validation and formatting")
struct APODDateTests {
    
    /// Helper: builds a GMT date from year/month/day with a safe failure path.
    private func gmtDate(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return try #require(Calendar.posixGMT.date(from: components))
    }
    
    @Test("Accepts the earliest valid APOD date (1995-06-16)")
    func acceptsEarliestDate() {
        let date = APODDate.earliest
        #expect(APODDate(date: date) != nil)
    }
    
    @Test("Rejects dates before 1995-06-16")
    func rejectsPre1995Dates() throws {
        let tooEarly = try gmtDate(year: 1995, month: 6, day: 15)
        #expect(APODDate(date: tooEarly) == nil)
    }
    
    @Test("Rejects dates more than one day past `now`")
    func rejectsFutureDates() throws {
        let now = try gmtDate(year: 2024, month: 6, day: 15)
        let twoDaysAhead = try gmtDate(year: 2024, month: 6, day: 17)
        #expect(APODDate(date: twoDaysAhead, now: now) == nil)
    }
    
    @Test("Accepts `now` as today")
    func acceptsToday() throws {
        let now = try gmtDate(year: 2024, month: 6, day: 15)
        #expect(APODDate(date: now, now: now) != nil)
    }
    
    @Test("Accepts tomorrow within the one-day grace window")
    func acceptsTomorrowGraceWindow() throws {
        let now = try gmtDate(year: 2024, month: 6, day: 15)
        let tomorrow = try gmtDate(year: 2024, month: 6, day: 16)
        #expect(APODDate(date: tomorrow, now: now) != nil)
    }
    
    @Test("APODDate normalizes to start of day")
    func normalizesToStartOfDay() throws {
        // Build two moments on the same GMT calendar day: 02:00 and 14:00.
        // Using DateComponents instead of epoch literals so the intent is
        // clear — both must fall on 2024-06-15 GMT.
        let dayStart = try gmtDate(year: 2024, month: 6, day: 15)
        let earlyMorning = dayStart.addingTimeInterval(2 * 3600)   // 02:00 GMT
        let afternoon = dayStart.addingTimeInterval(14 * 3600)     // 14:00 GMT
        
        let earlyAPOD = try #require(APODDate(date: earlyMorning))
        let afternoonAPOD = try #require(APODDate(date: afternoon))
        
        #expect(earlyAPOD == afternoonAPOD, "Same calendar day should produce equal APODDates")
    }
    
    @Test("API string format is YYYY-MM-DD")
    func apiStringFormat() throws {
        let date = try gmtDate(year: 2024, month: 1, day: 15)
        let apod = try #require(APODDate(date: date))
        #expect(apod.apiString == "2024-01-15")
    }
}
