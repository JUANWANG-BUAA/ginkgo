# Flutter 功能域：library

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/library/` 的页面、域内组件与模型。

## 目录

- [features/library/library_area_page.dart](#featureslibrarylibraryareapagedart) (1)
- [features/library/library_books_models.dart](#featureslibrarylibrarybooksmodelsdart) (5)
- [features/library/library_books_page.dart](#featureslibrarylibrarybookspagedart) (1)
- [features/library/library_cards.dart](#featureslibrarylibrarycardsdart) (4)
- [features/library/library_controller.dart](#featureslibrarylibrarycontrollerdart) (1)
- [features/library/library_controls.dart](#featureslibrarylibrarycontrolsdart) (5)
- [features/library/library_history_page.dart](#featureslibrarylibraryhistorypagedart) (1)
- [features/library/library_holdings_page.dart](#featureslibrarylibraryholdingspagedart) (1)
- [features/library/library_loans_page.dart](#featureslibrarylibraryloanspagedart) (1)
- [features/library/library_page.dart](#featureslibrarylibrarypagedart) (1)
- [features/library/library_seat_page.dart](#featureslibrarylibraryseatpagedart) (1)
- [features/library/library_slot_page.dart](#featureslibrarylibraryslotpagedart) (1)
- [features/library/library_stats_models.dart](#featureslibrarylibrarystatsmodelsdart) (5)
- [features/library/library_stats_page.dart](#featureslibrarylibrarystatspagedart) (1)
- [features/library/library_widgets.dart](#featureslibrarylibrarywidgetsdart) (6)

## features/library/library_area_page.dart

- `class LibraryAreaPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.
  <sub>class · features/library/library_area_page.dart:12</sub>
    - `const LibraryAreaPage({ super.key, required this.service, required this.venue, required this.onReservationChanged, required this.onViewReservations, });`  <sub>:13</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:20</sub>
    - `State<LibraryAreaPage> createState() => …`  <sub>:25</sub>

## features/library/library_books_models.dart

- `class BookHit`
  <sub>class · features/library/library_books_models.dart:6</sub>
    - `String get displayTitle => …`  <sub>:22</sub>
    - `String get factLine => …`  <sub>:24</sub>
- `class BookPage`
  <sub>class · features/library/library_books_models.dart:30</sub>
- `class BookHolding` — One physical copy. Status stays the school's own text; it is never turned
  <sub>class · features/library/library_books_models.dart:50</sub>
    - `String get place => …`  <sub>:60</sub>
- `BookPage bookPage(String payload) => …`
  <sub>function · features/library/library_books_models.dart:66</sub>
- `List<BookHolding> bookHoldings(String payload) => …`
  <sub>function · features/library/library_books_models.dart:69</sub>

## features/library/library_books_page.dart

- `class LibraryBooksPage extends StatefulWidget` — Public OPAC search. Anonymous, read-only and never personal: holdings are
  <sub>class · features/library/library_books_page.dart:15</sub>
    - `const LibraryBooksPage({super.key, required this.service});`  <sub>:16</sub>
    - `State<LibraryBooksPage> createState() => …`  <sub>:19</sub>

## features/library/library_cards.dart

- `class LibraryBookCard extends StatelessWidget` — One catalogue hit. The call number and the fact line are shown only when
  <sub>class · features/library/library_cards.dart:15</sub>
    - `const LibraryBookCard({super.key, required this.hit, required this.onTap});`  <sub>:16</sub>
    - `Widget build(BuildContext context) => …`  <sub>:22</sub>
- `class LibraryHoldingCard extends StatelessWidget` — One physical copy. The status stays the school's own text; it is never
  <sub>class · features/library/library_cards.dart:73</sub>
    - `const LibraryHoldingCard({ super.key, required this.holding, required this.repeatedCallNo, });`  <sub>:74</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:84</sub>
- `class LibraryVenueMeter extends StatelessWidget` — Venue capacity has three readable states: a quiet thin bar while seats
  <sub>class · features/library/library_cards.dart:111</sub>
    - `const LibraryVenueMeter({super.key, required this.venue, this.onTap});`  <sub>:112</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:120</sub>
- `Widget librarySeatRow( BuildContext context, { required Key groupKey, required LibrarySeat seat, required bool roundedTop, required bool roundedBottom, required bool hasSeparator, required bool reserveEnabled, required bool submitting, required VoidCallback onReserve, }) => …` — One seat row inside the seat list. The reserve action is offered only for
  <sub>function · features/library/library_cards.dart:229</sub>

## features/library/library_controller.dart

- `class LibraryController extends ChangeNotifier` — One library page owns its read snapshots and post-write readback queue.
  <sub>class · features/library/library_controller.dart:11</sub>
    - `bool loadingBookings = false, loadingVenues = false, submitting = false;`  <sub>:26</sub>
    - `final Set<String> uncertainActions = {…}`  <sub>:27</sub>
    - `bool get busy => …`  <sub>:33</sub>
    - `void invalidate() => …` — Drops every in-flight read at its next await: call when the account or  <sub>:38</sub>
    - `Future<void> load({bool force = false}) => …`  <sub>:44</sub>
    - `Future<void> loadVenues({bool force = false}) => …`  <sub>:99</sub>
    - `Future<void> loadBookings({bool force = false}) => …`  <sub>:167</sub>
    - `Future<void> reservationChanged() async {…}` — A pre-write read must finish before the forced read can be published.  <sub>:207</sub>
    - `Future<void> perform(LibraryBooking booking, String action) async {…}` — The page has already obtained explicit confirmation for this action.  <sub>:217</sub>
    - `void dispose() {…}`  <sub>:254</sub>

## features/library/library_controls.dart

- `class LibrarySearchField extends StatelessWidget` — The catalogue search field: one magnifier row with a submit button. The
  <sub>class · features/library/library_controls.dart:9</sub>
    - `const LibrarySearchField({ super.key, required this.controller, required this.placeholder, required this.onSubmit, required this.busy, this.boxKey, this.searchKey, this.submitKey, this.submitLabel = '检索', });`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:32</sub>
- `class LibraryFilterField extends StatelessWidget` — A free-text filter over a list that is already on screen. It filters
  <sub>class · features/library/library_controls.dart:81</sub>
    - `const LibraryFilterField({ super.key, required this.placeholder, required this.onChanged, this.filterKey, });`  <sub>:82</sub>
    - `Widget build(BuildContext context) => …`  <sub>:94</sub>
- `class LibrarySortControl extends StatelessWidget` — The sort selector of the public catalogue: one segmented control plus a
  <sub>class · features/library/library_controls.dart:103</sub>
    - `const LibrarySortControl({ super.key, required this.sort, required this.descending, required this.busy, required this.onSortChanged, required this.onDirectionToggled, this.rowKey, this.sortKey, this.directionKey, this.options = const {'relevance': '相关度', 'pub_year': '出版年', 'title': '题名'}, });`  <sub>:104</sub>
    - `Widget build(BuildContext context) => …`  <sub>:128</sub>
- `class LibraryPager extends StatelessWidget` — The pager of a school-paged list. The current page is always stated in
  <sub>class · features/library/library_controls.dart:168</sub>
    - `const LibraryPager({ super.key, required this.page, required this.hasMore, required this.busy, required this.onPrevious, required this.onNext, this.previousKey, this.nextKey, this.labelKey, });`  <sub>:169</sub>
    - `Widget build(BuildContext context) => …`  <sub>:191</sub>
- `class LibraryPageButtons extends StatelessWidget` — The plain previous / next controls of a list that the school pages. The
  <sub>class · features/library/library_controls.dart:246</sub>
    - `const LibraryPageButtons({ super.key, required this.canGoPrevious, required this.canGoNext, required this.onPrevious, required this.onNext, this.previousKey, this.nextKey, this.spread = true, });`  <sub>:247</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:270</sub>

## features/library/library_history_page.dart

- `class LibraryHistoryPage extends StatefulWidget` — member/seat is a read-only POST. Page failures never advance the cursor.
  <sub>class · features/library/library_history_page.dart:12</sub>
    - `const LibraryHistoryPage({super.key, required this.service});`  <sub>:13</sub>
    - `State<LibraryHistoryPage> createState() => …`  <sub>:16</sub>

## features/library/library_holdings_page.dart

- `class LibraryHoldingsPage extends StatefulWidget` — The copies the school holds for one catalogue record. The status text is
  <sub>class · features/library/library_holdings_page.dart:13</sub>
    - `const LibraryHoldingsPage({ super.key, required this.service, required this.bibId, required this.title, });`  <sub>:14</sub>
    - `State<LibraryHoldingsPage> createState() => …`  <sub>:24</sub>

## features/library/library_loans_page.dart

- `class LibraryLoansPage extends StatefulWidget` — Private records exist only while this page is active. No background reads.
  <sub>class · features/library/library_loans_page.dart:12</sub>
    - `const LibraryLoansPage({super.key, this.gateway, this.officialGateway});`  <sub>:13</sub>
    - `State<LibraryLoansPage> createState() => …`  <sub>:20</sub>

## features/library/library_page.dart

- `class LibraryPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.
  <sub>class · features/library/library_page.dart:20</sub>
    - `const LibraryPage({super.key, required this.service});`  <sub>:21</sub>
    - `State<LibraryPage> createState() => …`  <sub>:24</sub>

## features/library/library_seat_page.dart

- `class LibrarySeatPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.
  <sub>class · features/library/library_seat_page.dart:17</sub>
    - `const LibrarySeatPage({ super.key, required this.service, required this.area, required this.slot, required this.onReservationChanged, required this.onViewReservations, });`  <sub>:18</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:26</sub>
    - `State<LibrarySeatPage> createState() => …`  <sub>:32</sub>

## features/library/library_slot_page.dart

- `class LibrarySlotPage extends StatefulWidget` — Library hierarchy and explicit, single-attempt booking actions.
  <sub>class · features/library/library_slot_page.dart:11</sub>
    - `const LibrarySlotPage({ super.key, required this.service, required this.area, required this.onReservationChanged, required this.onViewReservations, });`  <sub>:12</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:19</sub>
    - `State<LibrarySlotPage> createState() => …`  <sub>:24</sub>

## features/library/library_stats_models.dart

- `class CountPair`
  <sub>class · features/library/library_stats_models.dart:6</sub>
    - `const CountPair({required this.available, required this.total});`  <sub>:7</sub>
- `class ReadingRoom`
  <sub>class · features/library/library_stats_models.dart:15</sub>
- `class LibraryCampusStats`
  <sub>class · features/library/library_stats_models.dart:24</sub>
- `class LibraryStatsSnapshot`
  <sub>class · features/library/library_stats_models.dart:46</sub>
- `LibraryStatsSnapshot libraryStats(String payload) {…}`
  <sub>function · features/library/library_stats_models.dart:56</sub>

## features/library/library_stats_page.dart

- `class LibraryStatsPage extends StatefulWidget` — Public counts are a snapshot, not a promise that a resource is bookable.
  <sub>class · features/library/library_stats_page.dart:14</sub>
    - `const LibraryStatsPage({super.key, required this.service});`  <sub>:15</sub>
    - `State<LibraryStatsPage> createState() => …`  <sub>:18</sub>

## features/library/library_widgets.dart

- `class LibrarySectionStatus extends StatelessWidget` — Inline status for a section that is still loading or that failed while
  <sub>class · features/library/library_widgets.dart:14</sub>
    - `const LibrarySectionStatus({ super.key, required this.id, required this.loading, required this.hasSnapshot, required this.failure, required this.retry, });`  <sub>:15</sub>
    - `Widget build(BuildContext context) => …`  <sub>:31</sub>
- `class LibraryDisclosureToggle extends StatelessWidget` — The toggle of a collapsible read-only note. The label states the current
  <sub>class · features/library/library_widgets.dart:54</sub>
    - `const LibraryDisclosureToggle({ super.key, required this.label, required this.expanded, required this.onToggle, this.toggleKey, });`  <sub>:55</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:69</sub>
- `class LibraryNoteText extends StatelessWidget` — The body of a read-only note that the reader opened on purpose.
  <sub>class · features/library/library_widgets.dart:113</sub>
    - `const LibraryNoteText({super.key, required this.text});`  <sub>:114</sub>
    - `Widget build(BuildContext context) => …`  <sub>:119</sub>
- `String libraryActionLabel(String action) => …` — The human label of one booking action. The same mapping is used by the
  <sub>function · features/library/library_widgets.dart:135</sub>
- `IconData libraryActionIcon(String action) => …` — The icon of one booking action.
  <sub>function · features/library/library_widgets.dart:144</sub>
- `CupertinoDynamicColor? libraryActionTint(String action) => …` — The semantic tint of one booking action. Actions without a tint keep the
  <sub>function · features/library/library_widgets.dart:153</sub>
