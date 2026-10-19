import SwiftUI

struct IOSInlineMessage: View {
  let text: String
  let systemImage: String
  let tint: Color

  init(_ text: String, systemImage: String = "info.circle", tint: Color = .secondary) {
    self.text = text
    self.systemImage = systemImage
    self.tint = tint
  }

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.footnote)
      .foregroundStyle(tint)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct IOSCourseTime: View {
  let meeting: CourseMeeting

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(meeting.startTime ?? "第 \(meeting.startSection) 节")
        .font(.subheadline.monospacedDigit().weight(.medium))
      Text(meeting.endTime.map { "– \($0)" } ?? "– 第 \(meeting.endSection) 节")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .frame(minWidth: 62, alignment: .leading)
  }
}
