# Flutter 功能域：cgyy

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/cgyy/` 的页面、域内组件与模型。

## 目录

- [features/cgyy/cgyy_booking_fields.dart](#featurescgyycgyybookingfieldsdart) (3)
- [features/cgyy/cgyy_booking_form.dart](#featurescgyycgyybookingformdart) (5)
- [features/cgyy/cgyy_booking_page.dart](#featurescgyycgyybookingpagedart) (1)
- [features/cgyy/cgyy_booking_slots.dart](#featurescgyycgyybookingslotsdart) (1)
- [features/cgyy/cgyy_booking_write.dart](#featurescgyycgyybookingwritedart) (2)
- [features/cgyy/cgyy_captcha_page.dart](#featurescgyycgyycaptchapagedart) (1)
- [features/cgyy/cgyy_day_page.dart](#featurescgyycgyydaypagedart) (1)
- [features/cgyy/cgyy_day_view.dart](#featurescgyycgyydayviewdart) (8)
- [features/cgyy/cgyy_gateway.dart](#featurescgyycgyygatewaydart) (5)
- [features/cgyy/cgyy_lock_code_page.dart](#featurescgyycgyylockcodepagedart) (1)
- [features/cgyy/cgyy_models.dart](#featurescgyycgyymodelsdart) (20)
- [features/cgyy/cgyy_order_detail_page.dart](#featurescgyycgyyorderdetailpagedart) (1)
- [features/cgyy/cgyy_page.dart](#featurescgyycgyypagedart) (1)
- [features/cgyy/cgyy_review_page.dart](#featurescgyycgyyreviewpagedart) (1)
- [features/cgyy/cgyy_widgets.dart](#featurescgyycgyywidgetsdart) (7)

## features/cgyy/cgyy_booking_fields.dart

- `class CgyyBookingTextField extends StatelessWidget` — A labelled booking field. The label doubles as the placeholder and as the
  <sub>class · features/cgyy/cgyy_booking_fields.dart:10</sub>
    - `const CgyyBookingTextField({ super.key, required this.label, required this.controller, this.number = false, this.multiline = false, this.enabled = true, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) => …`  <sub>:24</sub>
- `class CgyyParticipantStepper extends StatelessWidget` — The participant counter. The stepper never leaves the 1–100 range the
  <sub>class · features/cgyy/cgyy_booking_fields.dart:44</sub>
    - `const CgyyParticipantStepper({ super.key, required this.value, required this.onChanged, this.enabled = true, });`  <sub>:45</sub>
    - `Widget build(BuildContext context) => …`  <sub>:56</sub>
- `class CgyyPurposePicker extends StatelessWidget` — The activity type picker. The anchored menu keeps every option above the
  <sub>class · features/cgyy/cgyy_booking_fields.dart:87</sub>
    - `const CgyyPurposePicker({ super.key, required this.purposes, required this.purposeId, required this.onChanged, this.enabled = true, });`  <sub>:88</sub>
    - `Widget build(BuildContext context) => …`  <sub>:101</sub>

## features/cgyy/cgyy_booking_form.dart

- `class CgyyVenueSection extends StatelessWidget` — The venue and the date of the requested booking. Both are read-only: the
  <sub>class · features/cgyy/cgyy_booking_form.dart:12</sub>
    - `const CgyyVenueSection({ super.key, required this.siteName, required this.date, });`  <sub>:13</sub>
    - `Widget build(BuildContext context) => …`  <sub>:21</sub>
- `class CgyySlotSection extends StatelessWidget` — The venues and their bookable slots. One venue can be chosen per booking
  <sub>class · features/cgyy/cgyy_booking_form.dart:32</sub>
    - `const CgyySlotSection({ super.key, required this.loading, required this.loaded, required this.choices, required this.selectedSpaceId, required this.selectedTimeIds, required this.onToggleSlot, this.enabled = true, });`  <sub>:33</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:51</sub>
- `class CgyyDetailsSection extends StatelessWidget` — The details the school asks for. The values stay in memory for this form
  <sub>class · features/cgyy/cgyy_booking_form.dart:79</sub>
    - `const CgyyDetailsSection({ super.key, required this.purposes, required this.purposeId, required this.phone, required this.theme, required this.content, required this.joiners, required this.participantCount, required this.philosophy, required this.offSchool, required this.onSelectPurpose, required this.onStepParticipant, required this.onTogglePhilosophy, required this.onToggleOffSchool, this.enabled = true, });`  <sub>:80</sub>
    - `Widget build(BuildContext context) => …`  <sub>:109</sub>
- `class CgyyNoticeSection extends StatelessWidget` — A short guidance line shown after the form acted on the user.
  <sub>class · features/cgyy/cgyy_booking_form.dart:161</sub>
    - `const CgyyNoticeSection({super.key, required this.message});`  <sub>:162</sub>
    - `Widget build(BuildContext context) => …`  <sub>:166</sub>
- `class CgyyBookingActionsSection extends StatelessWidget` — The actions of the booking form. Only one write path is offered and the
  <sub>class · features/cgyy/cgyy_booking_form.dart:178</sub>
    - `const CgyyBookingActionsSection({ super.key, required this.busy, required this.loading, required this.review, required this.enabled, required this.onSubmit, required this.onRefresh, required this.onLeave, });`  <sub>:179</sub>
    - `Widget build(BuildContext context) => …`  <sub>:193</sub>

## features/cgyy/cgyy_booking_page.dart

- `class CgyyBookingPage extends StatefulWidget` — Mirrors IOSCgyyView's grouped native form and explicit confirmation flow.
  <sub>class · features/cgyy/cgyy_booking_page.dart:14</sub>
    - `const CgyyBookingPage({ super.key, required this.gateway, required this.siteId, required this.siteName, required this.date, });`  <sub>:15</sub>
    - `State<CgyyBookingPage> createState() => …`  <sub>:26</sub>

## features/cgyy/cgyy_booking_slots.dart

- `class CgyySlotGrid extends StatelessWidget` — One venue's bookable slots.
  <sub>class · features/cgyy/cgyy_booking_slots.dart:12</sub>
    - `const CgyySlotGrid({ super.key, required this.spaceId, required this.spaceName, required this.slots, required this.selectedSpaceId, required this.selectedTimeIds, required this.onToggle, this.enabled = true, });`  <sub>:13</sub>
    - `bool isSelected(CgyyBookingChoice slot) => …`  <sub>:31</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:35</sub>

## features/cgyy/cgyy_booking_write.dart

- `class CgyyBookingFailure implements Exception` — The booking command failed before a draft existed.
  <sub>class · features/cgyy/cgyy_booking_write.dart:14</sub>
    - `const CgyyBookingFailure();`  <sub>:15</sub>
- `class CgyyBookingDraft` — The booking form values as one snapshot.
  <sub>class · features/cgyy/cgyy_booking_write.dart:23</sub>
    - `const CgyyBookingDraft({ required this.siteId, required this.siteName, required this.date, required this.spaceId, required this.spaceName, required this.timeIds, required this.times, required this.participantCount, required this.purposeId, required this.purposeName, required this.phone, required this.theme, required this.content, required this.joiners, required this.philosophy, required this.offSchool, });`  <sub>:24</sub>
    - `bool get isComplete => …` — Whether the draft carries everything the school requires: one venue,  <sub>:53</sub>
    - `String get summary => …` — The confirmation text shared by the dialog and the captcha page.  <sub>:68</sub>
    - `Map<String, Object?> get payload => …` — The draft request the school receives.  <sub>:84</sub>

## features/cgyy/cgyy_captcha_page.dart

- `class CgyyCaptchaPage extends StatefulWidget` — School jigsaw verification. The drag is performed manually by the user;
  <sub>class · features/cgyy/cgyy_captcha_page.dart:16</sub>
    - `const CgyyCaptchaPage({ super.key, required this.gateway, required this.challenge, required this.summary, required this.consumedChallenges, });`  <sub>:17</sub>
    - `State<CgyyCaptchaPage> createState() => …`  <sub>:29</sub>

## features/cgyy/cgyy_day_page.dart

- `class CgyyDayPage extends StatefulWidget`
  <sub>class · features/cgyy/cgyy_day_page.dart:19</sub>
    - `const CgyyDayPage({ super.key, required this.demo, this.site, this.loader, this.service, this.bookingGateway, });`  <sub>:20</sub>
    - `State<CgyyDayPage> createState() => …`  <sub>:36</sub>

## features/cgyy/cgyy_day_view.dart

- `class CgyyWriteGuardSection extends StatelessWidget` — The local write protection banner. It stays visible while the last write
  <sub>class · features/cgyy/cgyy_day_view.dart:13</sub>
    - `const CgyyWriteGuardSection({ super.key, required this.guardKnown, required this.enabled, required this.onReview, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) => …`  <sub>:24</sub>
- `class CgyySiteQuerySection extends StatelessWidget` — The queried venue and the day the slots belong to.
  <sub>class · features/cgyy/cgyy_day_view.dart:45</sub>
    - `const CgyySiteQuerySection({ super.key, required this.site, required this.date, required this.enabled, required this.onChooseDate, });`  <sub>:46</sub>
    - `Widget build(BuildContext context) => …`  <sub>:59</sub>
- `class CgyyBookingEntrySection extends StatelessWidget` — The entry that opens the booking form. It stays disabled while the write
  <sub>class · features/cgyy/cgyy_day_view.dart:104</sub>
    - `const CgyyBookingEntrySection({ super.key, required this.enabled, required this.onTap, });`  <sub>:105</sub>
    - `Widget build(BuildContext context) => …`  <sub>:114</sub>
- `List<Widget> cgyyDaySlots(BuildContext context, CgyyDay day) => …` — The heading and one section per space of the queried day. A slot is shown
  <sub>function · features/cgyy/cgyy_day_view.dart:130</sub>
- `class CgyyOrderListSection extends StatelessWidget` — The most recent bookings the school returned.
  <sub>class · features/cgyy/cgyy_day_view.dart:172</sub>
    - `const CgyyOrderListSection({ super.key, required this.orders, required this.onOpen, });`  <sub>:173</sub>
    - `Widget build(BuildContext context) => …`  <sub>:182</sub>
- `class CgyyOrderManageSection extends StatelessWidget` — The bookings that may still be cancelled. The school decides which ones
  <sub>class · features/cgyy/cgyy_day_view.dart:209</sub>
    - `const CgyyOrderManageSection({ super.key, required this.orders, required this.enabled, required this.onCancel, });`  <sub>:210</sub>
    - `Widget build(BuildContext context) => …`  <sub>:221</sub>
- `Future<DateTime?> cgyyPickDate(BuildContext context, DateTime initial) async {…}` — The date picker of the day page. Returns the picked date, or null when the
  <sub>function · features/cgyy/cgyy_day_view.dart:239</sub>
- `String cgyyDisplayDate(String value) {…}` — The school date plus its weekday, shown wherever a raw date is presented.
  <sub>function · features/cgyy/cgyy_day_view.dart:287</sub>

## features/cgyy/cgyy_gateway.dart

- `typedef CgyyLoader = Future<live.ReadOnlyResponse> Function(` — Loader signature shared by the CGYY hub and the day/orders page.
  <sub>typedef · features/cgyy/cgyy_gateway.dart:7</sub>
- `Future<live.ReadOnlyResponse> cgyyRead({ required CgyyLoader? loader, required CgyyGateway? service, required String kind, required int siteId, required String date, required bool forceRefresh, }) async {…}` — Reads CGYY data through the injected loader or the injected campus gateway.
  <sub>function · features/cgyy/cgyy_gateway.dart:19</sub>
- `Future<live.ReadOnlyResponse> cgyyOrderDetail({ required int orderId, CgyyLoader? loader, CgyyGateway? service, bool forceRefresh = false, }) => …`
  <sub>function · features/cgyy/cgyy_gateway.dart:46</sub>
- `Future<live.ReadOnlyResponse> cgyyLockCode({ CgyyLoader? loader, CgyyGateway? service, bool forceRefresh = false, }) => …`
  <sub>function · features/cgyy/cgyy_gateway.dart:60</sub>
- `Future<CgyyWriteStatus> cgyyReadWriteStatus(CgyyBookingGateway gateway) async {…}` — Reads the local write-protection state of the last CGYY write. A failed or
  <sub>function · features/cgyy/cgyy_gateway.dart:75</sub>

## features/cgyy/cgyy_lock_code_page.dart

- `class CgyyLockCodePage extends StatefulWidget`
  <sub>class · features/cgyy/cgyy_lock_code_page.dart:10</sub>
    - `const CgyyLockCodePage({ super.key, this.demo = false, this.loader, this.service, });`  <sub>:11</sub>
    - `State<CgyyLockCodePage> createState() => …`  <sub>:23</sub>

## features/cgyy/cgyy_models.dart

- `class CgyySite`
  <sub>class · features/cgyy/cgyy_models.dart:7</sub>
- `class CgyySlot`
  <sub>class · features/cgyy/cgyy_models.dart:22</sub>
- `class CgyySpace`
  <sub>class · features/cgyy/cgyy_models.dart:30</sub>
- `class CgyyDay`
  <sub>class · features/cgyy/cgyy_models.dart:42</sub>
- `class CgyyOrder` — Approval labels follow API §6B and the existing CgyyModels.swift mapping.
  <sub>class · features/cgyy/cgyy_models.dart:56</sub>
    - `String get statusLabel {…}`  <sub>:73</sub>
    - `String get summary => …`  <sub>:103</sub>
- `class CgyyBookingChoice`
  <sub>class · features/cgyy/cgyy_models.dart:112</sub>
- `class CgyyPurpose`
  <sub>class · features/cgyy/cgyy_models.dart:123</sub>
- `class CgyyBookingOptions`
  <sub>class · features/cgyy/cgyy_models.dart:132</sub>
- `class CgyyChallenge` — Jigsaw challenge images stay raw data URLs; decoding happens in the widget
  <sub>class · features/cgyy/cgyy_models.dart:151</sub>
- `class CgyyReviewSnapshot`
  <sub>class · features/cgyy/cgyy_models.dart:160</sub>
- `class CgyyActionResult` — One write-flow result envelope. An unrecognized state stays `unknown`
  <sub>class · features/cgyy/cgyy_models.dart:174</sub>
    - `static const knownStates = {…}`  <sub>:202</sub>
    - `bool get isKnown => …`  <sub>:220</sub>
    - `bool get requiresReview => …`  <sub>:221</sub>
    - `bool get isChallenge => …`  <sub>:222</sub>
    - `bool get isReady => …`  <sub>:223</sub>
    - `bool get isReviewRequired => …`  <sub>:224</sub>
- `class CgyyWriteStatus` — The guard status of the last local write; anything but ready/uncertain
  <sub>class · features/cgyy/cgyy_models.dart:229</sub>
- `CgyyActionResult cgyyActionResult(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:237</sub>
- `CgyyWriteStatus cgyyWriteStatus(String payload) {…}`
  <sub>function · features/cgyy/cgyy_models.dart:240</sub>
- `List<CgyySite> cgyySites(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:249</sub>
- `CgyyDay cgyyDay(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:254</sub>
- `List<CgyyOrder> cgyyOrders(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:257</sub>
- `CgyyOrder cgyyOrder(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:262</sub>
- `class CgyyLockCode`
  <sub>class · features/cgyy/cgyy_models.dart:265</sub>
    - `bool get hasPassword => …`  <sub>:286</sub>
    - `bool get hasUpcomingReservation => …`  <sub>:288</sub>
    - `String get location => …`  <sub>:294</sub>
- `CgyyLockCode cgyyLockCodeData(String payload) => …`
  <sub>function · features/cgyy/cgyy_models.dart:301</sub>

## features/cgyy/cgyy_order_detail_page.dart

- `class CgyyOrderDetailPage extends StatefulWidget`
  <sub>class · features/cgyy/cgyy_order_detail_page.dart:10</sub>
    - `const CgyyOrderDetailPage({ super.key, required this.orderId, this.demo = false, this.loader, this.service, });`  <sub>:11</sub>
    - `State<CgyyOrderDetailPage> createState() => …`  <sub>:25</sub>

## features/cgyy/cgyy_page.dart

- `class CgyyPage extends StatefulWidget`
  <sub>class · features/cgyy/cgyy_page.dart:16</sub>
    - `const CgyyPage({ super.key, this.demo = false, this.loader, this.service, this.bookingGateway, });`  <sub>:17</sub>
    - `State<CgyyPage> createState() => …`  <sub>:31</sub>

## features/cgyy/cgyy_review_page.dart

- `class CgyyReviewPage extends StatefulWidget` — A fresh, visible review snapshot, not a background read-and-unlock action.
  <sub>class · features/cgyy/cgyy_review_page.dart:12</sub>
    - `const CgyyReviewPage({super.key, required this.gateway});`  <sub>:13</sub>
    - `State<CgyyReviewPage> createState() => …`  <sub>:16</sub>

## features/cgyy/cgyy_widgets.dart

- `Widget cgyySiteContent(CgyySite site, {bool chevron = false}) {…}` — Venue card content shared by the hub page and the day query page.
  <sub>function · features/cgyy/cgyy_widgets.dart:9</sub>
- `class CgyyConfirmDialog extends StatelessWidget` — Two-action confirmation dialog shared by every CGYY write. The route guard
  <sub>class · features/cgyy/cgyy_widgets.dart:35</sub>
    - `const CgyyConfirmDialog({ super.key, required this.title, required this.content, required this.cancelLabel, required this.confirmLabel, this.confirmKey, this.destructive = false, this.isDefault = false, });`  <sub>:36</sub>
    - `Widget build(BuildContext context) => …`  <sub>:50</sub>
- `Future<bool> showCgyyConfirmDialog( BuildContext context, { required String title, required String content, required String cancelLabel, required String confirmLabel, Key? confirmKey, bool destructive = false, bool isDefault = false, }) async {…}` — Shows a CGYY confirmation and resolves to true only after an explicit
  <sub>function · features/cgyy/cgyy_widgets.dart:79</sub>
- `class CgyyInteractiveRow extends StatefulWidget` — Inset rows inherit Cupertino press feedback and add a quiet pointer state.
  <sub>class · features/cgyy/cgyy_widgets.dart:106</sub>
    - `const CgyyInteractiveRow({ super.key, required this.child, required this.onTap, });`  <sub>:107</sub>
    - `State<CgyyInteractiveRow> createState() => …`  <sub>:115</sub>
- `class CgyyTileContent extends StatelessWidget`
  <sub>class · features/cgyy/cgyy_widgets.dart:141</sub>
    - `const CgyyTileContent({ super.key, required this.icon, required this.tint, required this.title, required this.detail, this.badges = const [], this.chevron = false, });`  <sub>:142</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:157</sub>
- `class CgyySlotRow extends StatelessWidget`
  <sub>class · features/cgyy/cgyy_widgets.dart:223</sub>
    - `const CgyySlotRow({super.key, required this.time, required this.status});`  <sub>:224</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:227</sub>
- `class SemanticsLabelIcon extends StatelessWidget` — Icon with a readable semantics label for icon-only stepper buttons.
  <sub>class · features/cgyy/cgyy_widgets.dart:267</sub>
    - `const SemanticsLabelIcon({ super.key, required this.label, required this.icon, });`  <sub>:268</sub>
    - `Widget build(BuildContext context) => …`  <sub>:276</sub>
