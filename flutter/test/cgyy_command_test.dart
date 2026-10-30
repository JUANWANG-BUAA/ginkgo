import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/cgyy_commands.dart';

void main() {
  test('typed CGYY commands preserve the existing write payloads', () {
    const draft = CgyyBookingDraft(
      siteId: 1,
      siteName: '合成场馆',
      date: '2026-10-30',
      spaceId: 2,
      spaceName: '合成空间',
      timeIds: [3, 4],
      times: ['08:00', '09:00'],
      participantCount: '2',
      purposeId: 5,
      purposeName: '学习研讨类',
      phone: '13800138000',
      theme: '合成主题',
      content: '合成内容',
      joiners: '李文',
      philosophy: true,
      offSchool: false,
    );

    expect(const CgyyStatusCommand().toPayload(), {'action': 'status'});
    expect(
      const CgyyOptionsCommand(siteId: 1, date: '2026-10-30').toPayload(),
      {'action': 'options', 'site_id': 1, 'date': '2026-10-30'},
    );
    expect(const CgyyPrepareCommand(draft).toPayload(), {
      'action': 'prepare',
      'booking': {
        'site_id': 1,
        'date': '2026-10-30',
        'space_id': 2,
        'time_ids': [3, 4],
        'phone': '13800138000',
        'theme': '合成主题',
        'purpose_type': 5,
        'joiner_num': 2,
        'activity_content': '合成内容',
        'joiners': '李文',
        'philosophy': true,
        'off_school': false,
      },
    });
    expect(
      const CgyySubmitCommand(
        challengeId: 'challenge',
        x: 12.5,
        width: 320,
      ).toPayload(),
      {
        'action': 'submit',
        'challenge_id': 'challenge',
        'x': 12.5,
        'width': 320,
      },
    );
    expect(const CgyyCancelCommand(7).toPayload(), {
      'action': 'cancel',
      'order_id': 7,
    });
    expect(const CgyyReviewCommand().toPayload(), {'action': 'review'});
    expect(const CgyyAcknowledgeCommand('review-id').toPayload(), {
      'action': 'acknowledge',
      'review_id': 'review-id',
    });
  });
}
