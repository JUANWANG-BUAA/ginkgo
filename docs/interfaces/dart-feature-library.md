# Flutter 功能域：library

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/library/` 的页面、域内组件与模型。

## 目录

- [features/library/library_area_page.dart](#featureslibrarylibraryareapagedart) (1)
- [features/library/library_books_models.dart](#featureslibrarylibrarybooksmodelsdart) (3)
- [features/library/library_books_page.dart](#featureslibrarylibrarybookspagedart) (1)
- [features/library/library_cards.dart](#featureslibrarylibrarycardsdart) (3)
- [features/library/library_controller.dart](#featureslibrarylibrarycontrollerdart) (1)
- [features/library/library_controls.dart](#featureslibrarylibrarycontrolsdart) (5)
- [features/library/library_history_page.dart](#featureslibrarylibraryhistorypagedart) (1)
- [features/library/library_holdings_page.dart](#featureslibrarylibraryholdingspagedart) (1)
- [features/library/library_loans_page.dart](#featureslibrarylibraryloanspagedart) (1)
- [features/library/library_page.dart](#featureslibrarylibrarypagedart) (1)
- [features/library/library_seat_page.dart](#featureslibrarylibraryseatpagedart) (1)
- [features/library/library_slot_page.dart](#featureslibrarylibraryslotpagedart) (1)
- [features/library/library_stats_models.dart](#featureslibrarylibrarystatsmodelsdart) (4)
- [features/library/library_stats_page.dart](#featureslibrarylibrarystatspagedart) (1)
- [features/library/library_widgets.dart](#featureslibrarylibrarywidgetsdart) (5)

## features/library/library_area_page.dart

- `class LibraryAreaPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>class · features/library/library_area_page.dart:13</sub>
    - `const LibraryAreaPage( {…}`  <sub>:14</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:21</sub>
    - `State<LibraryAreaPage> createState() => _LibraryAreaPageState();`  <sub>:26</sub>

## features/library/library_books_models.dart

- `class BookHit`  
  <sub>class · features/library/library_books_models.dart:6</sub>
    - `String get displayTitle => title.isNotEmpty ? title : '未命名书目';`  <sub>:22</sub>
    - `String get factLine => [author, publisher, year].where((part) => part.isNotEmpty).join(' · ');`  <sub>:24</sub>
- `class BookPage`  
  <sub>class · features/library/library_books_models.dart:30</sub>
- `class BookHolding` — One physical copy. Status stays the school's own text; it is never turned  
  <sub>class · features/library/library_books_models.dart:50</sub>
    - `String get place => [library, location].where((part) => part.isNotEmpty).join(' · ');`  <sub>:60</sub>

## features/library/library_books_page.dart

- `class LibraryBooksPage extends StatefulWidget` — Public OPAC search. Anonymous, read-only and never personal: holdings are  
  <sub>class · features/library/library_books_page.dart:15</sub>
    - `const LibraryBooksPage( {…}`  <sub>:16</sub>
    - `State<LibraryBooksPage> createState() => _LibraryBooksPageState();`  <sub>:19</sub>

## features/library/library_cards.dart

- `class LibraryBookCard extends StatelessWidget` — One catalogue hit. The call number and the fact line are shown only when  
  <sub>class · features/library/library_cards.dart:15</sub>
    - `const LibraryBookCard( {…}`  <sub>:16</sub>
    - `Widget build(BuildContext context) => AppleListTile( title: Text( hit.displayTitle, max … ding: const EdgeInsets.only(top: 2), child: Text( '索书号 $ {…}`  <sub>:26</sub>
- `class LibraryHoldingCard extends StatelessWidget` — One physical copy. The status stays the school's own text; it is never  
  <sub>class · features/library/library_cards.dart:77</sub>
    - `const LibraryHoldingCard( {…}`  <sub>:78</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:88</sub>
- `class LibraryVenueMeter extends StatelessWidget` — Venue capacity has three readable states: a quiet thin bar while seats  
  <sub>class · features/library/library_cards.dart:117</sub>
    - `const LibraryVenueMeter( {…}`  <sub>:118</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:126</sub>

## features/library/library_controller.dart

- `class LibraryController extends ChangeNotifier` — One library page owns its read snapshots and post-write readback queue.  
  <sub>class · features/library/library_controller.dart:9</sub>
    - `bool loadingBookings = false, loadingVenues = false, submitting = false;`  <sub>:16</sub>
    - `final Set<String> uncertainActions = {…}`  <sub>:17</sub>
    - `bool get busy => loadingBookings \|\| loadingVenues;`  <sub>:22</sub>
    - `void invalidate() => _generation++;` — Drops every in-flight read at its next await: call when the account or  <sub>:27</sub>
    - `Future<void> load( {…}`  <sub>:33</sub>
    - `Future<void> loadVenues( {…}`  <sub>:86</sub>
    - `Future<void> loadBookings( {…}`  <sub>:116</sub>
    - `Future<void> reservationChanged() async {…}` — A pre-write read must finish before the forced read can be published.  <sub>:148</sub>
    - `Future<void> perform(LibraryBooking booking, String action) async {…}` — The page has already obtained explicit confirmation for this action.  <sub>:154</sub>
    - `void dispose() {…}`  <sub>:186</sub>

## features/library/library_controls.dart

- `class LibrarySearchField extends StatelessWidget` — The catalogue search field: one magnifier row with a submit button. The  
  <sub>class · features/library/library_controls.dart:8</sub>
    - `const LibrarySearchField( {…}`  <sub>:9</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:31</sub>
- `class LibraryFilterField extends StatelessWidget` — A free-text filter over a list that is already on screen. It filters  
  <sub>class · features/library/library_controls.dart:80</sub>
    - `const LibraryFilterField( {…}`  <sub>:81</sub>
    - `Widget build(BuildContext context) => CupertinoSearchTextField( key: filterKey, placeholder: placeholder, onChanged: onChanged, );`  <sub>:93</sub>
- `class LibrarySortControl extends StatelessWidget` — The sort selector of the public catalogue: one segmented control plus a  
  <sub>class · features/library/library_controls.dart:102</sub>
    - `const LibrarySortControl( {…}`  <sub>:103</sub>
    - `Widget build(BuildContext context) => Row( key: rowKey, children: [ Expanded( child: Cu … ntrol<String>( key: sortKey, groupValue: sort, children: {…}`  <sub>:127</sub>
- `class LibraryPager extends StatelessWidget` — The pager of a school-paged list. The current page is always stated in  
  <sub>class · features/library/library_controls.dart:167</sub>
    - `const LibraryPager( {…}`  <sub>:168</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(4, 2, … n(CupertinoIcons.chevron_right, size: 15), ], ), ), ], ), );`  <sub>:190</sub>
- `class LibraryPageButtons extends StatelessWidget` — The plain previous / next controls of a list that the school pages. The  
  <sub>class · features/library/library_controls.dart:245</sub>
    - `const LibraryPageButtons( {…}`  <sub>:246</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:269</sub>

## features/library/library_history_page.dart

- `class LibraryHistoryPage extends StatefulWidget` — member/seat is a read-only POST. Page failures never advance the cursor.  
  <sub>class · features/library/library_history_page.dart:12</sub>
    - `const LibraryHistoryPage( {…}`  <sub>:13</sub>
    - `State<LibraryHistoryPage> createState() => _LibraryHistoryPageState();`  <sub>:16</sub>

## features/library/library_holdings_page.dart

- `class LibraryHoldingsPage extends StatefulWidget` — The copies the school holds for one catalogue record. The status text is  
  <sub>class · features/library/library_holdings_page.dart:14</sub>
    - `const LibraryHoldingsPage( {…}`  <sub>:15</sub>
    - `State<LibraryHoldingsPage> createState() => _LibraryHoldingsPageState();`  <sub>:25</sub>

## features/library/library_loans_page.dart

- `class LibraryLoansPage extends StatefulWidget` — Private records exist only while this page is active. No background reads.  
  <sub>class · features/library/library_loans_page.dart:12</sub>
    - `const LibraryLoansPage( {…}`  <sub>:13</sub>
    - `State<LibraryLoansPage> createState() => _LibraryLoansPageState();`  <sub>:16</sub>

## features/library/library_page.dart

- `class LibraryPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>class · features/library/library_page.dart:20</sub>
    - `const LibraryPage( {…}`  <sub>:21</sub>
    - `State<LibraryPage> createState() => _LibraryPageState();`  <sub>:24</sub>

## features/library/library_seat_page.dart

- `class LibrarySeatPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>class · features/library/library_seat_page.dart:18</sub>
    - `const LibrarySeatPage( {…}`  <sub>:19</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:27</sub>
    - `State<LibrarySeatPage> createState() => _LibrarySeatPageState();`  <sub>:33</sub>

## features/library/library_slot_page.dart

- `class LibrarySlotPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>class · features/library/library_slot_page.dart:12</sub>
    - `const LibrarySlotPage( {…}`  <sub>:13</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:20</sub>
    - `State<LibrarySlotPage> createState() => _LibrarySlotPageState();`  <sub>:25</sub>

## features/library/library_stats_models.dart

- `class CountPair`  
  <sub>class · features/library/library_stats_models.dart:6</sub>
    - `const CountPair( {…}`  <sub>:7</sub>
- `class ReadingRoom`  
  <sub>class · features/library/library_stats_models.dart:15</sub>
- `class LibraryCampusStats`  
  <sub>class · features/library/library_stats_models.dart:24</sub>
- `class LibraryStatsSnapshot`  
  <sub>class · features/library/library_stats_models.dart:46</sub>

## features/library/library_stats_page.dart

- `class LibraryStatsPage extends StatefulWidget` — Public counts are a snapshot, not a promise that a resource is bookable.  
  <sub>class · features/library/library_stats_page.dart:12</sub>
    - `const LibraryStatsPage( {…}`  <sub>:13</sub>
    - `State<LibraryStatsPage> createState() => _LibraryStatsPageState();`  <sub>:16</sub>

## features/library/library_widgets.dart

- `class LibraryPageHeader extends StatelessWidget` — The section header every library drill-down page uses. The trailing  
  <sub>class · features/library/library_widgets.dart:14</sub>
    - `const LibraryPageHeader( {…}`  <sub>:15</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:32</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), section … e: 17) : const Icon(CupertinoIcons.refresh, size: 24), ), );`  <sub>:35</sub>
- `class LibraryEmptyState extends StatelessWidget` — One shared empty / error state for every library list. A failure keeps  
  <sub>class · features/library/library_widgets.dart:56</sub>
    - `const LibraryEmptyState( {…}`  <sub>:57</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: animateSize, children: … , action: action, onAction: onAction, error: error, ), ], );`  <sub>:77</sub>
- `class LibrarySectionStatus extends StatelessWidget` — Inline status for a section that is still loading or that failed while  
  <sub>class · features/library/library_widgets.dart:94</sub>
    - `const LibrarySectionStatus( {…}`  <sub>:95</sub>
    - `Widget build(BuildContext context) => AppleListTile( key: Key('library-$id-status'), le … ontal: 12), onPressed: retry, child: const Text('重试'), ), );`  <sub>:111</sub>
- `class LibraryDisclosureToggle extends StatelessWidget` — The toggle of a collapsible read-only note. The label states the current  
  <sub>class · features/library/library_widgets.dart:134</sub>
    - `const LibraryDisclosureToggle( {…}`  <sub>:135</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:149</sub>
- `class LibraryNoteText extends StatelessWidget` — The body of a read-only note that the reader opened on purpose.  
  <sub>class · features/library/library_widgets.dart:193</sub>
    - `const LibraryNoteText( {…}`  <sub>:194</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(24, 0 … upertinoColors.secondaryLabel.resolveFrom(context), ), ), );`  <sub>:199</sub>
