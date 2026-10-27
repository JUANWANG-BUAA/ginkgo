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
- [features/cgyy/cgyy_day_view.dart](#featurescgyycgyydayviewdart) (5)
- [features/cgyy/cgyy_gateway.dart](#featurescgyycgyygatewaydart) (1)
- [features/cgyy/cgyy_models.dart](#featurescgyycgyymodelsdart) (12)
- [features/cgyy/cgyy_page.dart](#featurescgyycgyypagedart) (1)
- [features/cgyy/cgyy_review_page.dart](#featurescgyycgyyreviewpagedart) (1)
- [features/cgyy/cgyy_widgets.dart](#featurescgyycgyywidgetsdart) (7)

## features/cgyy/cgyy_booking_fields.dart

- `class CgyyBookingTextField extends StatelessWidget` — A labelled booking field. The label doubles as the placeholder and as the  
  <sub>class · features/cgyy/cgyy_booking_fields.dart:10</sub>
    - `const CgyyBookingTextField( {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Semantics( label: label, child: CupertinoTextForm … 4 : 1, enabled: enabled, maxLength: number ? 11 : 500, ), );`  <sub>:24</sub>
- `class CgyyParticipantStepper extends StatelessWidget` — The participant counter. The stepper never leaves the 1–100 range the  
  <sub>class · features/cgyy/cgyy_booking_fields.dart:44</sub>
    - `const CgyyParticipantStepper( {…}`  <sub>:45</sub>
    - `Widget build(BuildContext context) => AppleListTile( title: Text('参与人数：$value 人'), trai … ( label: '增加参与人数', icon: CupertinoIcons.plus, ), ), ], ), );`  <sub>:56</sub>
- `class CgyyPurposePicker extends StatelessWidget` — The activity type picker. The anchored menu keeps every option above the  
  <sub>class · features/cgyy/cgyy_booking_fields.dart:87</sub>
    - `const CgyyPurposePicker( {…}`  <sub>:88</sub>
    - `Widget build(BuildContext context) => Builder( builder: (anchor) => AppleListTile( titl … on_up_chevron_down, size: 14), onTap: enabled ? () async {…}`  <sub>:101</sub>

## features/cgyy/cgyy_booking_form.dart

- `class CgyyVenueSection extends StatelessWidget` — The venue and the date of the requested booking. Both are read-only: the  
  <sub>class · features/cgyy/cgyy_booking_form.dart:12</sub>
    - `const CgyyVenueSection( {…}`  <sub>:13</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('场地与日期'), childr … stTile(title: const Text('日期'), subtitle: Text(date)), ], );`  <sub>:21</sub>
- `class CgyySlotSection extends StatelessWidget` — The venues and their bookable slots. One venue can be chosen per booking  
  <sub>class · features/cgyy/cgyy_booking_form.dart:32</sub>
    - `const CgyySlotSection( {…}`  <sub>:33</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:51</sub>
- `class CgyyDetailsSection extends StatelessWidget` — The details the school asks for. The values stay in memory for this form  
  <sub>class · features/cgyy/cgyy_booking_form.dart:82</sub>
    - `const CgyyDetailsSection( {…}`  <sub>:83</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('预约信息'), footer: … ed ? (value) => onToggleOffSchool(value) : null, ), ), ], );`  <sub>:112</sub>
- `class CgyyNoticeSection extends StatelessWidget` — A short guidance line shown after the form acted on the user.  
  <sub>class · features/cgyy/cgyy_booking_form.dart:170</sub>
    - `const CgyyNoticeSection( {…}`  <sub>:171</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleListTile( leading: … (CupertinoIcons.info_circle), title: Text(message), ), ], );`  <sub>:175</sub>
- `class CgyyBookingActionsSection extends StatelessWidget` — The actions of the booking form. Only one write path is offered and the  
  <sub>class · features/cgyy/cgyy_booking_form.dart:187</sub>
    - `const CgyyBookingActionsSection( {…}`  <sub>:188</sub>
    - `Widget build(BuildContext context) => AppleSection( footer: const Text('实验功能，真实预约往返仍需人工 … y ? null : onLeave, child: const Text('返回并核对我的预约'), ), ], );`  <sub>:202</sub>

## features/cgyy/cgyy_booking_page.dart

- `class CgyyBookingPage extends StatefulWidget` — Mirrors IOSCgyyView's grouped native form and explicit confirmation flow.  
  <sub>class · features/cgyy/cgyy_booking_page.dart:14</sub>
    - `const CgyyBookingPage( {…}`  <sub>:15</sub>
    - `State<CgyyBookingPage> createState() => _CgyyBookingPageState();`  <sub>:26</sub>

## features/cgyy/cgyy_booking_slots.dart

- `class CgyySlotGrid extends StatelessWidget` — One venue's bookable slots.  
  <sub>class · features/cgyy/cgyy_booking_slots.dart:10</sub>
    - `const CgyySlotGrid( {…}`  <sub>:11</sub>
    - `bool isSelected(CgyyBookingChoice slot) => selectedSpaceId == spaceId && selectedTimeIds.contains(slot.timeId);`  <sub>:29</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:33</sub>

## features/cgyy/cgyy_booking_write.dart

- `class CgyyBookingFailure implements Exception` — The booking command failed before a draft existed.  
  <sub>class · features/cgyy/cgyy_booking_write.dart:14</sub>
    - `const CgyyBookingFailure();`  <sub>:15</sub>
- `class CgyyBookingDraft` — The booking form values as one snapshot.  
  <sub>class · features/cgyy/cgyy_booking_write.dart:23</sub>
    - `const CgyyBookingDraft( {…}`  <sub>:24</sub>
    - `bool get isComplete => siteId > 0 &&` — Whether the draft carries everything the school requires: one venue,  <sub>:53</sub>
    - `String get summary => [ '场馆：$siteName', '日期：$date', '空间：$spaceName', '时段：$ {…}` — The confirmation text shared by the dialog and the captcha page.  <sub>:68</sub>
    - `Map<String, Object?> get payload => {…}` — The draft request the school receives.  <sub>:84</sub>

## features/cgyy/cgyy_captcha_page.dart

- `class CgyyCaptchaPage extends StatefulWidget` — School jigsaw verification. The drag is performed manually by the user;  
  <sub>class · features/cgyy/cgyy_captcha_page.dart:16</sub>
    - `const CgyyCaptchaPage( {…}`  <sub>:17</sub>
    - `State<CgyyCaptchaPage> createState() => _CgyyCaptchaPageState();`  <sub>:29</sub>

## features/cgyy/cgyy_day_page.dart

- `class CgyyDayPage extends StatefulWidget`  
  <sub>class · features/cgyy/cgyy_day_page.dart:18</sub>
    - `const CgyyDayPage( {…}`  <sub>:19</sub>
    - `State<CgyyDayPage> createState() => _CgyyDayPageState();`  <sub>:31</sub>

## features/cgyy/cgyy_day_view.dart

- `class CgyyWriteGuardSection extends StatelessWidget` — The local write protection banner. It stays visible while the last write  
  <sub>class · features/cgyy/cgyy_day_view.dart:13</sub>
    - `const CgyyWriteGuardSection( {…}`  <sub>:14</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('写入保护'), footer: … ? onReview : null, child: const Text('读取最新记录并核对'), ), ], );`  <sub>:24</sub>
- `class CgyySiteQuerySection extends StatelessWidget` — The queried venue and the day the slots belong to.  
  <sub>class · features/cgyy/cgyy_day_view.dart:47</sub>
    - `const CgyySiteQuerySection( {…}`  <sub>:48</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ cgyySiteContent(site), … onPressed: enabled ? onChooseDate : null, ), ], ), ), ], );`  <sub>:61</sub>
- `class CgyyBookingEntrySection extends StatelessWidget` — The entry that opens the booking form. It stays disabled while the write  
  <sub>class · features/cgyy/cgyy_day_view.dart:106</sub>
    - `const CgyyBookingEntrySection( {…}`  <sub>:107</sub>
    - `Widget build(BuildContext context) => AppleSection( footer: const Text('提交前重新核对空档；实验写入功 … cgyy-open-booking'), onTap: enabled ? onTap : null, ), ], );`  <sub>:116</sub>
- `class CgyyOrderListSection extends StatelessWidget` — The most recent bookings the school returned.  
  <sub>class · features/cgyy/cgyy_day_view.dart:180</sub>
    - `const CgyyOrderListSection( {…}`  <sub>:181</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('最近最多 20 条'), ch … : order.place.isEmpty ? '预约记录' : order.place, detail: '$ {…}`  <sub>:185</sub>
- `class CgyyOrderManageSection extends StatelessWidget` — The bookings that may still be cancelled. The school decides which ones  
  <sub>class · features/cgyy/cgyy_day_view.dart:208</sub>
    - `const CgyyOrderManageSection( {…}`  <sub>:209</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('预约管理'), footer: … r.canCancel) AppleListTile( key: ValueKey('cgyy-cancel-$ {…}`  <sub>:220</sub>

## features/cgyy/cgyy_gateway.dart

- `typedef CgyyLoader = Future<live.ReadOnlyResponse> Function(` — Loader signature shared by the CGYY hub and the day/orders page.  
  <sub>typedef · features/cgyy/cgyy_gateway.dart:7</sub>

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
    - `String get summary => [ '订单 $id', place.isNotEmpty ? place : '地点未提供', date, time, statusLabel, ].join('\n');`  <sub>:103</sub>
- `class CgyyBookingChoice`  
  <sub>class · features/cgyy/cgyy_models.dart:112</sub>
- `class CgyyPurpose`  
  <sub>class · features/cgyy/cgyy_models.dart:123</sub>
- `class CgyyBookingOptions`  
  <sub>class · features/cgyy/cgyy_models.dart:132</sub>
- `class CgyyChallenge` — Jigsaw challenge images stay raw data URLs; decoding happens in the widget  
  <sub>class · features/cgyy/cgyy_models.dart:149</sub>
- `class CgyyReviewSnapshot`  
  <sub>class · features/cgyy/cgyy_models.dart:158</sub>
- `class CgyyActionResult` — One write-flow result envelope. An unrecognized state stays `unknown`  
  <sub>class · features/cgyy/cgyy_models.dart:172</sub>
    - `static const knownStates = {…}`  <sub>:200</sub>
    - `bool get isKnown => knownStates.contains(state);`  <sub>:218</sub>
    - `bool get requiresReview => state == 'uncertain' \|\| state == 'accepted';`  <sub>:219</sub>
    - `bool get isChallenge => state == 'challenge';`  <sub>:220</sub>
    - `bool get isReady => state == 'ready';`  <sub>:221</sub>
    - `bool get isReviewRequired => state == 'reviewRequired';`  <sub>:222</sub>
- `class CgyyWriteStatus` — The guard status of the last local write; anything but ready/uncertain  
  <sub>class · features/cgyy/cgyy_models.dart:227</sub>

## features/cgyy/cgyy_page.dart

- `class CgyyPage extends StatefulWidget`  
  <sub>class · features/cgyy/cgyy_page.dart:14</sub>
    - `const CgyyPage( {…}`  <sub>:15</sub>
    - `State<CgyyPage> createState() => _CgyyPageState();`  <sub>:20</sub>

## features/cgyy/cgyy_review_page.dart

- `class CgyyReviewPage extends StatefulWidget` — A fresh, visible review snapshot, not a background read-and-unlock action.  
  <sub>class · features/cgyy/cgyy_review_page.dart:12</sub>
    - `const CgyyReviewPage( {…}`  <sub>:13</sub>
    - `State<CgyyReviewPage> createState() => _CgyyReviewPageState();`  <sub>:16</sub>

## features/cgyy/cgyy_widgets.dart

- `class CgyyPageHeader extends StatelessWidget` — The CGYY page header shared by the booking and the review page. Section,  
  <sub>class · features/cgyy/cgyy_widgets.dart:36</sub>
    - `const CgyyPageHeader( {…}`  <sub>:37</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), section … 场馆并查看可预约空间', icon: CupertinoIcons.person_3, border: null, );`  <sub>:40</sub>
- `class CgyyStatusSection extends StatelessWidget` — Error and empty states share one block so the hub and the day page cannot  
  <sub>class · features/cgyy/cgyy_widgets.dart:51</sub>
    - `const CgyyStatusSection( {…}`  <sub>:52</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleEmptyState( title: … l ? null : '重试', onAction: onRetry, error: isError, ), ], );`  <sub>:63</sub>
- `class CgyyConfirmDialog extends StatelessWidget` — Two-action confirmation dialog shared by every CGYY write. The route guard  
  <sub>class · features/cgyy/cgyy_widgets.dart:78</sub>
    - `const CgyyConfirmDialog( {…}`  <sub>:79</sub>
    - `Widget build(BuildContext context) => CupertinoAlertDialog( title: Text(title), content … ontent), actions: [ CupertinoDialogAction( onPressed: () {…}`  <sub>:93</sub>
- `class CgyyInteractiveRow extends StatefulWidget` — Inset rows inherit Cupertino press feedback and add a quiet pointer state.  
  <sub>class · features/cgyy/cgyy_widgets.dart:149</sub>
    - `const CgyyInteractiveRow( {…}`  <sub>:150</sub>
    - `State<CgyyInteractiveRow> createState() => _CgyyInteractiveRowState();`  <sub>:158</sub>
- `class CgyyTileContent extends StatelessWidget`  
  <sub>class · features/cgyy/cgyy_widgets.dart:184</sub>
    - `const CgyyTileContent( {…}`  <sub>:185</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:200</sub>
- `class CgyySlotRow extends StatelessWidget`  
  <sub>class · features/cgyy/cgyy_widgets.dart:266</sub>
    - `const CgyySlotRow( {…}`  <sub>:267</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:270</sub>
- `class SemanticsLabelIcon extends StatelessWidget` — Icon with a readable semantics label for icon-only stepper buttons.  
  <sub>class · features/cgyy/cgyy_widgets.dart:310</sub>
    - `const SemanticsLabelIcon( {…}`  <sub>:311</sub>
    - `Widget build(BuildContext context) => Semantics(label: label, child: Icon(icon, size: 18));`  <sub>:319</sub>
