import '../application/contracts.dart';
import '../application/notices.dart';
import '../src/rust/api/live.dart' as live;

/// Native and demo both cross the bridge as the same typed DTO, so they share
/// one projection and cannot drift apart.
NoticesRead decodeNotices(live.NoticesResponse response) {
  final data = response.data;
  if (data == null) {
    return NoticesRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return NoticesRead(
    data: List.unmodifiable(
      data.map(
        (notice) => Notice(
          title: notice.title,
          summary: notice.summary,
          publishedAt: notice.publishedAt,
          url: notice.url,
        ),
      ),
    ),
    failure: response.failure,
  );
}
