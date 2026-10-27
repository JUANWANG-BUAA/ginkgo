# Flutter 功能域：cgyy

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/cgyy/` 的页面、域内组件与模型。

## CgyyBookingTextField (class)

- `class CgyyBookingTextField extends StatelessWidget {` — A labelled booking field. The label doubles as the placeholder and as the  
  <sub>features/cgyy/cgyy_booking_fields.dart:10</sub>
    - `const CgyyBookingTextField({ super.key, required this.label, required this.controller, this.number = false, this.multiline = false, this.enabled = tr…`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Semantics( label: label, child: CupertinoTextFormFieldRow( controller: controller, placeholder: label, keyboard…`  <sub>:24</sub>

## CgyyParticipantStepper (class)

- `class CgyyParticipantStepper extends StatelessWidget {` — The participant counter. The stepper never leaves the 1–100 range the  
  <sub>features/cgyy/cgyy_booking_fields.dart:44</sub>
    - `const CgyyParticipantStepper({ super.key, required this.value, required this.onChanged, this.enabled = true, });`  <sub>:45</sub>
    - `Widget build(BuildContext context) => AppleListTile( title: Text('参与人数：$value 人'), trailing: Row( mainAxisSize: MainAxisSize.min, children: [ Cuperti…`  <sub>:56</sub>

## CgyyPurposePicker (class)

- `class CgyyPurposePicker extends StatelessWidget {` — The activity type picker. The anchored menu keeps every option above the  
  <sub>features/cgyy/cgyy_booking_fields.dart:87</sub>
    - `const CgyyPurposePicker({ super.key, required this.purposes, required this.purposeId, required this.onChanged, this.enabled = true, });`  <sub>:88</sub>
    - `Widget build(BuildContext context) => Builder( builder: (anchor) => AppleListTile( title: const Text('活动类型'), additionalInfo: SizedBox( width: MediaQ…`  <sub>:101</sub>

## CgyyVenueSection (class)

- `class CgyyVenueSection extends StatelessWidget {` — The venue and the date of the requested booking. Both are read-only: the  
  <sub>features/cgyy/cgyy_booking_form.dart:12</sub>
    - `const CgyyVenueSection({ super.key, required this.siteName, required this.date, });`  <sub>:13</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('场地与日期'), children: [ AppleListTile(title: const Text('场地'), subtitle: Text(si…`  <sub>:21</sub>

## CgyySlotSection (class)

- `class CgyySlotSection extends StatelessWidget {` — The venues and their bookable slots. One venue can be chosen per booking  
  <sub>features/cgyy/cgyy_booking_form.dart:32</sub>
    - `const CgyySlotSection({ super.key, required this.loading, required this.loaded, required this.choices, required this.selectedSpaceId, required this.s…`  <sub>:33</sub>
    - `Widget build(BuildContext context) { final spaces = <int, String>{ for (final choice in choices) choice.spaceId: choice.spaceName, }; return AppleSec…`  <sub>:51</sub>

## CgyyDetailsSection (class)

- `class CgyyDetailsSection extends StatelessWidget {` — The details the school asks for. The values stay in memory for this form  
  <sub>features/cgyy/cgyy_booking_form.dart:82</sub>
    - `const CgyyDetailsSection({ super.key, required this.purposes, required this.purposeId, required this.phone, required this.theme, required this.conten…`  <sub>:83</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('预约信息'), footer: const Text('手机号与参与人仅用于本次学校预约，不保存在本机日志中。'), children: [ CgyyBo…`  <sub>:112</sub>

## CgyyNoticeSection (class)

- `class CgyyNoticeSection extends StatelessWidget {` — A short guidance line shown after the form acted on the user.  
  <sub>features/cgyy/cgyy_booking_form.dart:170</sub>
    - `const CgyyNoticeSection({super.key, required this.message});`  <sub>:171</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleListTile( leading: const Icon(CupertinoIcons.info_circle), title: Text(message),…`  <sub>:175</sub>

## CgyyBookingActionsSection (class)

- `class CgyyBookingActionsSection extends StatelessWidget {` — The actions of the booking form. Only one write path is offered and the  
  <sub>features/cgyy/cgyy_booking_form.dart:187</sub>
    - `const CgyyBookingActionsSection({ super.key, required this.busy, required this.loading, required this.review, required this.enabled, required this.on…`  <sub>:188</sub>
    - `Widget build(BuildContext context) => AppleSection( footer: const Text('实验功能，真实预约往返仍需人工验收。提交后需核对学校审批状态。'), children: [ CupertinoButton( onPressed: bu…`  <sub>:202</sub>

## CgyyBookingPage (class)

- `class CgyyBookingPage extends StatefulWidget {` — Mirrors IOSCgyyView's grouped native form and explicit confirmation flow.  
  <sub>features/cgyy/cgyy_booking_page.dart:14</sub>
    - `const CgyyBookingPage({ super.key, required this.gateway, required this.siteId, required this.siteName, required this.date, });`  <sub>:15</sub>
    - `State<CgyyBookingPage> createState() => _CgyyBookingPageState();`  <sub>:26</sub>

## CgyySlotGrid (class)

- `class CgyySlotGrid extends StatelessWidget {` — One venue's bookable slots.  
  <sub>features/cgyy/cgyy_booking_slots.dart:10</sub>
    - `const CgyySlotGrid({ super.key, required this.spaceId, required this.spaceName, required this.slots, required this.selectedSpaceId, required this.sel…`  <sub>:11</sub>
    - `bool isSelected(CgyyBookingChoice slot) => selectedSpaceId == spaceId && selectedTimeIds.contains(slot.timeId);`  <sub>:29</sub>
    - `Widget build(BuildContext context) { final accent = CupertinoTheme.of(context).primaryColor; return Padding( padding: const EdgeInsets.all(16), child…`  <sub>:33</sub>

## CgyyBookingFailure (class)

- `class CgyyBookingFailure implements Exception {` — The booking command failed before a draft existed.  
  <sub>features/cgyy/cgyy_booking_write.dart:14</sub>
    - `const CgyyBookingFailure();`  <sub>:15</sub>

## CgyyBookingDraft (class)

- `class CgyyBookingDraft {` — The booking form values as one snapshot.  
  <sub>features/cgyy/cgyy_booking_write.dart:23</sub>
    - `const CgyyBookingDraft({ required this.siteId, required this.siteName, required this.date, required this.spaceId, required this.spaceName, required t…`  <sub>:24</sub>
    - `bool get isComplete => siteId > 0 &&` — Whether the draft carries everything the school requires: one venue,  <sub>:53</sub>
    - `String get summary => [ '场馆：$siteName', '日期：$date', '空间：$spaceName', '时段：${times.join('、')}', '人数：$participantCount 人', '用途：$purposeName', '手机：$phone…` — The confirmation text shared by the dialog and the captcha page.  <sub>:68</sub>
    - `Map<String, Object?> get payload => { 'site_id': siteId, 'date': date, 'space_id': spaceId, 'time_ids': timeIds, 'phone': phone, 'theme': theme, 'pur…` — The draft request the school receives.  <sub>:84</sub>

## CgyyCaptchaPage (class)

- `class CgyyCaptchaPage extends StatefulWidget {` — School jigsaw verification. The drag is performed manually by the user;  
  <sub>features/cgyy/cgyy_captcha_page.dart:16</sub>
    - `const CgyyCaptchaPage({ super.key, required this.gateway, required this.challenge, required this.summary, required this.consumedChallenges, });`  <sub>:17</sub>
    - `State<CgyyCaptchaPage> createState() => _CgyyCaptchaPageState();`  <sub>:29</sub>

## CgyyDayPage (class)

- `class CgyyDayPage extends StatefulWidget {`  
  <sub>features/cgyy/cgyy_day_page.dart:18</sub>
    - `const CgyyDayPage({ super.key, required this.demo, this.site, this.loader, this.service, });`  <sub>:19</sub>
    - `State<CgyyDayPage> createState() => _CgyyDayPageState();`  <sub>:31</sub>

## CgyyWriteGuardSection (class)

- `class CgyyWriteGuardSection extends StatelessWidget {` — The local write protection banner. It stays visible while the last write  
  <sub>features/cgyy/cgyy_day_view.dart:13</sub>
    - `const CgyyWriteGuardSection({ super.key, required this.guardKnown, required this.enabled, required this.onReview, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('写入保护'), footer: const Text('预约记录出现不代表审批通过。核实前不会再次预约或取消。'), children: [ Paddin…`  <sub>:24</sub>

## CgyySiteQuerySection (class)

- `class CgyySiteQuerySection extends StatelessWidget {` — The queried venue and the day the slots belong to.  
  <sub>features/cgyy/cgyy_day_view.dart:47</sub>
    - `const CgyySiteQuerySection({ super.key, required this.site, required this.date, required this.enabled, required this.onChooseDate, });`  <sub>:48</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ cgyySiteContent(site), Padding( padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), c…`  <sub>:61</sub>

## CgyyBookingEntrySection (class)

- `class CgyyBookingEntrySection extends StatelessWidget {` — The entry that opens the booking form. It stays disabled while the write  
  <sub>features/cgyy/cgyy_day_view.dart:106</sub>
    - `const CgyyBookingEntrySection({ super.key, required this.enabled, required this.onTap, });`  <sub>:107</sub>
    - `Widget build(BuildContext context) => AppleSection( footer: const Text('提交前重新核对空档；实验写入功能，需手动验证并确认。'), children: [ AppleListTile( leading: const Icon(…`  <sub>:116</sub>

## CgyyOrderListSection (class)

- `class CgyyOrderListSection extends StatelessWidget {` — The most recent bookings the school returned.  
  <sub>features/cgyy/cgyy_day_view.dart:180</sub>
    - `const CgyyOrderListSection({super.key, required this.orders});`  <sub>:181</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('最近最多 20 条'), children: [ for (final order in orders) CgyyTileContent( icon: C…`  <sub>:185</sub>

## CgyyOrderManageSection (class)

- `class CgyyOrderManageSection extends StatelessWidget {` — The bookings that may still be cancelled. The school decides which ones  
  <sub>features/cgyy/cgyy_day_view.dart:208</sub>
    - `const CgyyOrderManageSection({ super.key, required this.orders, required this.enabled, required this.onCancel, });`  <sub>:209</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('预约管理'), footer: const Text('取消前会核对订单状态及开始前 4 小时限制；不符合条件不会发送请求。'), children: […`  <sub>:220</sub>

## CgyyLoader (typedef)

- `typedef CgyyLoader = Future<live.ReadOnlyResponse> Function({` — Loader signature shared by the CGYY hub and the day/orders page.  
  <sub>features/cgyy/cgyy_gateway.dart:7</sub>

## CgyySite (class)

- `class CgyySite {`  
  <sub>features/cgyy/cgyy_models.dart:7</sub>

## CgyySlot (class)

- `class CgyySlot {`  
  <sub>features/cgyy/cgyy_models.dart:22</sub>

## CgyySpace (class)

- `class CgyySpace {`  
  <sub>features/cgyy/cgyy_models.dart:30</sub>

## CgyyDay (class)

- `class CgyyDay {`  
  <sub>features/cgyy/cgyy_models.dart:42</sub>

## CgyyOrder (class)

- `class CgyyOrder {` — Approval labels follow API §6B and the existing CgyyModels.swift mapping.  
  <sub>features/cgyy/cgyy_models.dart:56</sub>
    - `String get statusLabel { final check = checkStatus; if (orderStatus == 2) return '已取消'; if (check != null && check < 0) { return switch (check) { -2 …`  <sub>:73</sub>
    - `String get summary => [ '订单 $id', place.isNotEmpty ? place : '地点未提供', date, time, statusLabel, ].join('\n');`  <sub>:103</sub>

## CgyyBookingChoice (class)

- `class CgyyBookingChoice {`  
  <sub>features/cgyy/cgyy_models.dart:112</sub>

## CgyyPurpose (class)

- `class CgyyPurpose {`  
  <sub>features/cgyy/cgyy_models.dart:123</sub>

## CgyyBookingOptions (class)

- `class CgyyBookingOptions {`  
  <sub>features/cgyy/cgyy_models.dart:132</sub>

## CgyyChallenge (class)

- `class CgyyChallenge {` — Jigsaw challenge images stay raw data URLs; decoding happens in the widget  
  <sub>features/cgyy/cgyy_models.dart:149</sub>

## CgyyReviewSnapshot (class)

- `class CgyyReviewSnapshot {`  
  <sub>features/cgyy/cgyy_models.dart:158</sub>

## CgyyActionResult (class)

- `class CgyyActionResult {` — One write-flow result envelope. An unrecognized state stays `unknown`  
  <sub>features/cgyy/cgyy_models.dart:172</sub>
    - `static const knownStates = { 'accepted', 'uncertain', 'rejected', 'not_submitted', 'notSubmitted', };`  <sub>:200</sub>
    - `bool get isKnown => knownStates.contains(state);`  <sub>:218</sub>
    - `bool get requiresReview => state == 'uncertain' \|\| state == 'accepted';`  <sub>:219</sub>
    - `bool get isChallenge => state == 'challenge';`  <sub>:220</sub>
    - `bool get isReady => state == 'ready';`  <sub>:221</sub>
    - `bool get isReviewRequired => state == 'reviewRequired';`  <sub>:222</sub>

## CgyyWriteStatus (class)

- `class CgyyWriteStatus {` — The guard status of the last local write; anything but ready/uncertain  
  <sub>features/cgyy/cgyy_models.dart:227</sub>

## CgyyPage (class)

- `class CgyyPage extends StatefulWidget {`  
  <sub>features/cgyy/cgyy_page.dart:14</sub>
    - `const CgyyPage({super.key, this.demo = false, this.loader, this.service});`  <sub>:15</sub>
    - `State<CgyyPage> createState() => _CgyyPageState();`  <sub>:20</sub>

## CgyyReviewPage (class)

- `class CgyyReviewPage extends StatefulWidget {` — A fresh, visible review snapshot, not a background read-and-unlock action.  
  <sub>features/cgyy/cgyy_review_page.dart:12</sub>
    - `const CgyyReviewPage({super.key, required this.gateway});`  <sub>:13</sub>
    - `State<CgyyReviewPage> createState() => _CgyyReviewPageState();`  <sub>:16</sub>

## CgyyPageHeader (class)

- `class CgyyPageHeader extends StatelessWidget {` — The CGYY page header shared by the booking and the review page. Section,  
  <sub>features/cgyy/cgyy_widgets.dart:36</sub>
    - `const CgyyPageHeader({super.key, required this.title});`  <sub>:37</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), section: '空间资源', subtitle: '选择场馆并查看可预约空间', icon: CupertinoIcons.perso…`  <sub>:40</sub>

## CgyyStatusSection (class)

- `class CgyyStatusSection extends StatelessWidget {` — Error and empty states share one block so the hub and the day page cannot  
  <sub>features/cgyy/cgyy_widgets.dart:51</sub>
    - `const CgyyStatusSection({ super.key, required this.title, required this.description, this.onRetry, this.isError = false, });`  <sub>:52</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleEmptyState( title: title, description: description, action: onRetry == null ? nu…`  <sub>:63</sub>

## CgyyConfirmDialog (class)

- `class CgyyConfirmDialog extends StatelessWidget {` — Two-action confirmation dialog shared by every CGYY write. The route guard  
  <sub>features/cgyy/cgyy_widgets.dart:78</sub>
    - `const CgyyConfirmDialog({ super.key, required this.title, required this.content, required this.cancelLabel, required this.confirmLabel, this.confirmK…`  <sub>:79</sub>
    - `Widget build(BuildContext context) => CupertinoAlertDialog( title: Text(title), content: Text(content), actions: [ CupertinoDialogAction( onPressed: …`  <sub>:93</sub>

## CgyyInteractiveRow (class)

- `class CgyyInteractiveRow extends StatefulWidget {` — Inset rows inherit Cupertino press feedback and add a quiet pointer state.  
  <sub>features/cgyy/cgyy_widgets.dart:149</sub>
    - `const CgyyInteractiveRow({ super.key, required this.child, required this.onTap, });`  <sub>:150</sub>
    - `State<CgyyInteractiveRow> createState() => _CgyyInteractiveRowState();`  <sub>:158</sub>

## CgyyTileContent (class)

- `class CgyyTileContent extends StatelessWidget {`  
  <sub>features/cgyy/cgyy_widgets.dart:184</sub>
    - `const CgyyTileContent({ super.key, required this.icon, required this.tint, required this.title, required this.detail, this.badges = const [], this.ch…`  <sub>:185</sub>
    - `Widget build(BuildContext context) { final color = tint.resolveFrom(context); return Padding( padding: const EdgeInsets.all(16), child: Row( crossAxi…`  <sub>:200</sub>

## CgyySlotRow (class)

- `class CgyySlotRow extends StatelessWidget {`  
  <sub>features/cgyy/cgyy_widgets.dart:266</sub>
    - `const CgyySlotRow({super.key, required this.time, required this.status});`  <sub>:267</sub>
    - `Widget build(BuildContext context) { final (tint, icon) = switch (status) { '空闲' => (AppleDesign.statusSuccess, CupertinoIcons.checkmark_circle), '不可…`  <sub>:270</sub>

## SemanticsLabelIcon (class)

- `class SemanticsLabelIcon extends StatelessWidget {` — Icon with a readable semantics label for icon-only stepper buttons.  
  <sub>features/cgyy/cgyy_widgets.dart:310</sub>
    - `const SemanticsLabelIcon({ super.key, required this.label, required this.icon, });`  <sub>:311</sub>
    - `Widget build(BuildContext context) => Semantics(label: label, child: Icon(icon, size: 18));`  <sub>:319</sub>
