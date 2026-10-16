import Foundation

struct LibraryOccupancyForecast: Equatable {
  let sampleCount: Int
  let estimatedUnavailableSeats: Int
  let totalSeats: Int
}

struct LibraryOccupancyTrendPoint: Identifiable, Equatable {
  let hour: Int
  let averageUnavailableRatio: Double
  let sampleCount: Int

  var id: Int { hour }
}

struct LibraryPeopleForecast: Equatable {
  let sampleCount: Int
  let estimatedPeople: Int
}

struct LibraryPeopleTrendPoint: Identifiable, Equatable {
  let hour: Int
  let averagePeople: Double
  let sampleCount: Int

  var id: Int { hour }
}

/// Stores one local aggregate per area, day, and hour. No account or seat identifiers are saved.
final class LibraryOccupancyHistory {
  private struct Sample: Codable {
    let areaID: String
    let day: String
    let weekday: Int
    let hour: Int
    let availableSeats: Int
    let totalSeats: Int
  }

  private struct PeopleSample: Codable {
    let campusID: String
    let day: String
    let weekday: Int
    let hour: Int
    let people: Int
  }

  private let defaults: UserDefaults
  private let key = "libraryOccupancyHistory.v1"
  private let peopleKey = "libraryPeopleHistory.v1"
  private let maximumAgeDays = 60
  private let maximumSamples = 4_000
  private var cachedSamples: [Sample]?
  private var cachedPeopleSamples: [PeopleSample]?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func clear() {
    defaults.removeObject(forKey: key)
    defaults.removeObject(forKey: peopleKey)
    cachedSamples = []
    cachedPeopleSamples = []
  }

  func record(areaID: String, availableSeats: Int, totalSeats: Int, at date: Date = Date()) {
    guard !areaID.isEmpty, totalSeats > 0 else { return }
    let calendar = Self.calendar
    let day = Self.dayFormatter.string(from: date)
    let sample = Sample(
      areaID: areaID,
      day: day,
      weekday: calendar.component(.weekday, from: date),
      hour: calendar.component(.hour, from: date),
      availableSeats: min(max(availableSeats, 0), totalSeats),
      totalSeats: totalSeats
    )
    var samples = loadSamples().filter { $0.day >= Self.minimumDay(from: date, days: maximumAgeDays) }
    samples.removeAll { $0.areaID == areaID && $0.day == day && $0.hour == sample.hour }
    samples.append(sample)
    if samples.count > maximumSamples {
      samples.sort {
        if $0.day != $1.day { return $0.day < $1.day }
        if $0.hour != $1.hour { return $0.hour < $1.hour }
        return $0.areaID < $1.areaID
      }
      samples = Array(samples.suffix(maximumSamples))
    }
    save(samples)
  }

  func recordPeople(_ snapshot: LibraryPublicStats) {
    for campus in snapshot.campuses {
      recordPeople(campusID: campus.id, people: campus.people, at: snapshot.fetchedAt)
    }
  }

  func recordPeople(campusID: String, people: Int, at date: Date = Date()) {
    guard !campusID.isEmpty, people >= 0 else { return }
    let day = Self.dayFormatter.string(from: date)
    let sample = PeopleSample(
      campusID: campusID,
      day: day,
      weekday: Self.calendar.component(.weekday, from: date),
      hour: Self.calendar.component(.hour, from: date),
      people: people
    )
    var samples = loadPeopleSamples().filter { $0.day >= Self.minimumDay(from: date, days: maximumAgeDays) }
    samples.removeAll { $0.campusID == campusID && $0.day == day && $0.hour == sample.hour }
    samples.append(sample)
    if samples.count > maximumSamples {
      samples.sort {
        if $0.day != $1.day { return $0.day < $1.day }
        if $0.hour != $1.hour { return $0.hour < $1.hour }
        return $0.campusID < $1.campusID
      }
      samples = Array(samples.suffix(maximumSamples))
    }
    savePeopleSamples(samples)
  }

  func sampleCount(areaID: String, weekday: Int, hour: Int, before date: Date = Date()) -> Int {
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    return loadSamples().filter {
      $0.areaID == areaID && $0.weekday == weekday && $0.hour == hour && $0.day >= firstDay && $0.day < today
    }.count
  }

  func forecast(
    areaID: String,
    weekday: Int,
    hour: Int,
    totalSeats: Int,
    before date: Date = Date()
  ) -> LibraryOccupancyForecast? {
    guard totalSeats > 0 else { return nil }
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    let samples = loadSamples().filter {
      $0.areaID == areaID && $0.weekday == weekday && $0.hour == hour &&
        $0.day >= firstDay && $0.day < today && $0.totalSeats > 0
    }
    guard samples.count >= 3 else { return nil }
    let unavailableRatios = samples.map { Double($0.totalSeats - $0.availableSeats) / Double($0.totalSeats) }
    let mean = unavailableRatios.reduce(0, +) / Double(unavailableRatios.count)
    return LibraryOccupancyForecast(
      sampleCount: samples.count,
      estimatedUnavailableSeats: Int((mean * Double(totalSeats)).rounded()),
      totalSeats: totalSeats
    )
  }

  func trend(areaID: String, weekday: Int, before date: Date = Date()) -> [LibraryOccupancyTrendPoint] {
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    let samples = loadSamples().filter {
      $0.areaID == areaID && $0.weekday == weekday && $0.day >= firstDay && $0.day <= today && $0.totalSeats > 0
    }
    let grouped = Dictionary(grouping: samples, by: \.hour)
    return grouped.keys.sorted().compactMap { hour in
      guard let hourSamples = grouped[hour], !hourSamples.isEmpty else { return nil }
      let unavailableRatios = hourSamples.map {
        Double($0.totalSeats - $0.availableSeats) / Double($0.totalSeats)
      }
      return LibraryOccupancyTrendPoint(
        hour: hour,
        averageUnavailableRatio: unavailableRatios.reduce(0, +) / Double(unavailableRatios.count),
        sampleCount: hourSamples.count
      )
    }
  }

  func peopleSampleCount(campusID: String, weekday: Int, hour: Int, before date: Date = Date()) -> Int {
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    return loadPeopleSamples().filter {
      $0.campusID == campusID && $0.weekday == weekday && $0.hour == hour && $0.day >= firstDay && $0.day < today
    }.count
  }

  func peopleForecast(
    campusID: String,
    weekday: Int,
    hour: Int,
    before date: Date = Date()
  ) -> LibraryPeopleForecast? {
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    let samples = loadPeopleSamples().filter {
      $0.campusID == campusID && $0.weekday == weekday && $0.hour == hour &&
        $0.day >= firstDay && $0.day < today
    }
    guard samples.count >= 3 else { return nil }
    let average = samples.map { Double($0.people) }.reduce(0, +) / Double(samples.count)
    return LibraryPeopleForecast(sampleCount: samples.count, estimatedPeople: Int(average.rounded()))
  }

  func peopleTrend(campusID: String, weekday: Int, before date: Date = Date()) -> [LibraryPeopleTrendPoint] {
    let today = Self.dayFormatter.string(from: date)
    let firstDay = Self.minimumDay(from: date, days: maximumAgeDays)
    let samples = loadPeopleSamples().filter {
      $0.campusID == campusID && $0.weekday == weekday && $0.day >= firstDay && $0.day <= today
    }
    let grouped = Dictionary(grouping: samples, by: \.hour)
    return grouped.keys.sorted().compactMap { hour in
      guard let hourSamples = grouped[hour], !hourSamples.isEmpty else { return nil }
      return LibraryPeopleTrendPoint(
        hour: hour,
        averagePeople: hourSamples.map { Double($0.people) }.reduce(0, +) / Double(hourSamples.count),
        sampleCount: hourSamples.count
      )
    }
  }

  static var currentWeekday: Int { calendar.component(.weekday, from: Date()) }
  static var currentHour: Int { calendar.component(.hour, from: Date()) }

  private func loadSamples() -> [Sample] {
    if let cachedSamples { return cachedSamples }
    guard let data = defaults.data(forKey: key),
          let samples = try? JSONDecoder().decode([Sample].self, from: data) else {
      cachedSamples = []
      return []
    }
    cachedSamples = samples
    return samples
  }

  private func save(_ samples: [Sample]) {
    guard let data = try? JSONEncoder().encode(samples) else { return }
    cachedSamples = samples
    defaults.set(data, forKey: key)
  }

  private func loadPeopleSamples() -> [PeopleSample] {
    if let cachedPeopleSamples { return cachedPeopleSamples }
    guard let data = defaults.data(forKey: peopleKey),
          let samples = try? JSONDecoder().decode([PeopleSample].self, from: data) else {
      cachedPeopleSamples = []
      return []
    }
    cachedPeopleSamples = samples
    return samples
  }

  private func savePeopleSamples(_ samples: [PeopleSample]) {
    guard let data = try? JSONEncoder().encode(samples) else { return }
    cachedPeopleSamples = samples
    defaults.set(data, forKey: peopleKey)
  }

  private static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
    return calendar
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static func minimumDay(from date: Date, days: Int) -> String {
    dayFormatter.string(from: calendar.date(byAdding: .day, value: -days, to: date) ?? date)
  }
}
