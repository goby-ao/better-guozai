import Foundation
import SwiftData
import UserNotifications

enum ReminderAuthorization: Equatable, Sendable {
  case notDetermined
  case denied
  case allowed

  init(_ status: UNAuthorizationStatus) {
    switch status {
    case .notDetermined:
      self = .notDetermined
    case .denied:
      self = .denied
    case .authorized, .provisional, .ephemeral:
      self = .allowed
    @unknown default:
      self = .denied
    }
  }
}

/// 统一管理本地提醒的稳定标识与重复日历通知。
enum ReminderScheduler {
  static let morningIdentifier = "guozai.reminder.morning"
  static let eveningIdentifier = "guozai.reminder.evening"
  static let maximumPendingOccurrencesPerTemplate = 6

  static func templateIdentifier(_ templateID: UUID) -> String {
    "guozai.reminder.template.\(templateID.uuidString.lowercased())"
  }

  static func templateIdentifiers(_ templateID: UUID) -> [String] {
    let base = templateIdentifier(templateID)
    return [base]
      + (1...7).map { "\(base).weekday.\($0)" }
      + (0..<maximumPendingOccurrencesPerTemplate).map { "\(base).occurrence.\($0)" }
  }

  static func authorization() async -> ReminderAuthorization {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return ReminderAuthorization(settings.authorizationStatus)
  }

  static func requestAuthorization() async -> ReminderAuthorization {
    do {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      )
    } catch {
      return .denied
    }
    return await authorization()
  }

  static func setMorningReminder(enabled: Bool, hour: Int, minute: Int) async throws {
    try await setDailyReminder(
      identifier: morningIdentifier,
      enabled: enabled,
      hour: hour,
      minute: minute,
      title: "果仔，新的一天开始啦 ☀️",
      body: "打开“果仔的一天”，看看今天有哪些成长任务。"
    )
  }

  static func setEveningReminder(enabled: Bool, hour: Int, minute: Int) async throws {
    try await setDailyReminder(
      identifier: eveningIdentifier,
      enabled: enabled,
      hour: hour,
      minute: minute,
      title: "来回顾今天吧 🌙",
      body: "记录今天的心情、星星和最骄傲的一件事。"
    )
  }

  static func setTemplateReminder(
    templateID: UUID,
    title: String,
    enabled: Bool,
    hour: Int,
    minute: Int,
    recurrenceKind: RecurrenceRule.Kind,
    weekdays: Set<Int>,
    start: LocalDay,
    end: LocalDay?,
    pauseStart: LocalDay?,
    pauseEnd: LocalDay?,
    now: Date = .now
  ) async throws {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: templateIdentifiers(templateID))
    guard enabled else { return }

    let pauses: [RecurrenceRule.Pause]
    if let pauseStart {
      pauses = [.init(
        start: pauseStart,
        end: pauseEnd ?? LocalDay(year: 9999, month: 12, day: 31)
      )]
    } else {
      pauses = []
    }
    let rule = RecurrenceRule(
      kind: recurrenceKind,
      start: start,
      end: end,
      weekdays: weekdays,
      pauses: pauses
    )
    let calendar = Calendar.guozaiGregorian
    let firstDay = LocalDay(date: now, calendar: calendar)
    let candidateDays = rule.upcomingDays(
      from: firstDay,
      limit: maximumPendingOccurrencesPerTemplate + 1,
      searchHorizonDays: 366,
      calendar: calendar
    )

    var scheduledCount = 0
    for day in candidateDays {
      guard
        scheduledCount < maximumPendingOccurrencesPerTemplate,
        let fireDate = notificationDate(
          for: day,
          hour: hour,
          minute: minute,
          calendar: calendar
        ),
        fireDate > now
      else { continue }

      try await addTemplateRequest(
        identifier: "\(templateIdentifier(templateID)).occurrence.\(scheduledCount)",
        title: title,
        fireDate: fireDate,
        calendar: calendar
      )
      scheduledCount += 1
    }
  }

  static func removeTemplateReminder(templateID: UUID) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: templateIdentifiers(templateID)
    )
  }

  static func remove(identifier: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
  }

  private static func setDailyReminder(
    identifier: String,
    enabled: Bool,
    hour: Int,
    minute: Int,
    title: String,
    body: String
  ) async throws {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [identifier])

    guard enabled else { return }

    var components = DateComponents()
    components.calendar = .current
    components.timeZone = .current
    components.hour = min(max(hour, 0), 23)
    components.minute = min(max(minute, 0), 59)

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    )
    try await center.add(request)
  }

  private static func addTemplateRequest(
    identifier: String,
    title: String,
    fireDate: Date,
    calendar: Calendar
  ) async throws {
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    components.calendar = calendar
    components.timeZone = calendar.timeZone

    let content = UNMutableNotificationContent()
    content.title = "任务提醒：\(title)"
    content.body = "准备好后，去完成今天的小目标吧。"
    content.sound = .default

    try await UNUserNotificationCenter.current().add(UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    ))
  }

  private static func notificationDate(
    for day: LocalDay,
    hour: Int,
    minute: Int,
    calendar: Calendar
  ) -> Date? {
    calendar.date(from: DateComponents(
      calendar: calendar,
      timeZone: calendar.timeZone,
      year: day.year,
      month: day.month,
      day: day.day,
      hour: min(max(hour, 0), 23),
      minute: min(max(minute, 0), 59)
    ))
  }
}

@MainActor
enum ReminderMaintenanceService {
  static func syncTemplateReminders(in context: ModelContext) async throws {
    guard await ReminderScheduler.authorization() == .allowed else { return }

    let templates = try context.fetch(FetchDescriptor<TaskTemplateRecord>())
    for template in templates {
      guard let start = LocalDay(key: template.startDayKey) else {
        ReminderScheduler.removeTemplateReminder(templateID: template.id)
        continue
      }

      let end = template.endDayKey.flatMap(LocalDay.init(key:))
      let pauseStart = template.pauseStartDayKey.flatMap(LocalDay.init(key:))
      let pauseEnd = template.pauseEndDayKey.flatMap(LocalDay.init(key:))
      let hasInvalidLifecycleDate =
        (template.endDayKey != nil && end == nil)
        || (template.pauseStartDayKey != nil && pauseStart == nil)
        || (template.pauseEndDayKey != nil && pauseEnd == nil)

      try await ReminderScheduler.setTemplateReminder(
        templateID: template.id,
        title: template.title,
        enabled: template.isActive
          && template.deletedAt == nil
          && template.reminderHour != nil
          && template.reminderMinute != nil
          && !hasInvalidLifecycleDate,
        hour: template.reminderHour ?? 17,
        minute: template.reminderMinute ?? 0,
        recurrenceKind: template.recurrenceKind,
        weekdays: template.weekdays,
        start: start,
        end: end,
        pauseStart: pauseStart,
        pauseEnd: pauseEnd
      )
    }
  }
}

enum ReminderPreferenceKey {
  static let morningEnabled = "reminder.morning.enabled"
  static let morningHour = "reminder.morning.hour"
  static let morningMinute = "reminder.morning.minute"
  static let eveningEnabled = "reminder.evening.enabled"
  static let eveningHour = "reminder.evening.hour"
  static let eveningMinute = "reminder.evening.minute"
}
