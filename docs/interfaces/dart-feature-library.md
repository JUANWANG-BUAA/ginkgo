# Flutter 功能域：library

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/library/` 的页面、域内组件与模型。

## LibraryAreaPage (class)

- `class LibraryAreaPage extends StatefulWidget {` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>features/library/library_area_page.dart:13</sub>
    - `const LibraryAreaPage({ super.key, required this.service, required this.venue, required this.onReservationChanged, required this.onViewReservations, …`  <sub>:14</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:21</sub>
    - `State<LibraryAreaPage> createState() => _LibraryAreaPageState();`  <sub>:26</sub>

## BookHit (class)

- `class BookHit {`  
  <sub>features/library/library_books_models.dart:6</sub>
    - `String get displayTitle => title.isNotEmpty ? title : '未命名书目';`  <sub>:22</sub>
    - `String get factLine => [author, publisher, year].where((part) => part.isNotEmpty).join(' · ');`  <sub>:24</sub>

## BookPage (class)

- `class BookPage {`  
  <sub>features/library/library_books_models.dart:30</sub>

## BookHolding (class)

- `class BookHolding {` — One physical copy. Status stays the school's own text; it is never turned  
  <sub>features/library/library_books_models.dart:50</sub>
    - `String get place => [library, location].where((part) => part.isNotEmpty).join(' · ');`  <sub>:60</sub>

## LibraryBooksPage (class)

- `class LibraryBooksPage extends StatefulWidget {` — Public OPAC search. Anonymous, read-only and never personal: holdings are  
  <sub>features/library/library_books_page.dart:15</sub>
    - `const LibraryBooksPage({super.key, required this.service});`  <sub>:16</sub>
    - `State<LibraryBooksPage> createState() => _LibraryBooksPageState();`  <sub>:19</sub>

## LibraryBookCard (class)

- `class LibraryBookCard extends StatelessWidget {` — One catalogue hit. The call number and the fact line are shown only when  
  <sub>features/library/library_cards.dart:15</sub>
    - `const LibraryBookCard({ super.key, required this.hit, required this.onTap, });`  <sub>:16</sub>
    - `Widget build(BuildContext context) => AppleListTile( title: Text( hit.displayTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextSt…`  <sub>:26</sub>

## LibraryHoldingCard (class)

- `class LibraryHoldingCard extends StatelessWidget {` — One physical copy. The status stays the school's own text; it is never  
  <sub>features/library/library_cards.dart:77</sub>
    - `const LibraryHoldingCard({ super.key, required this.holding, required this.repeatedCallNo, });`  <sub>:78</sub>
    - `Widget build(BuildContext context) { final secondary = CupertinoColors.tertiaryLabel.resolveFrom(context); return AppleListTile( title: Text( holding…`  <sub>:88</sub>

## LibraryVenueMeter (class)

- `class LibraryVenueMeter extends StatelessWidget {` — Venue capacity has three readable states: a quiet thin bar while seats  
  <sub>features/library/library_cards.dart:117</sub>
    - `const LibraryVenueMeter({super.key, required this.venue, this.onTap});`  <sub>:118</sub>
    - `Widget build(BuildContext context) { final known = venue.total > 0; final ratio = known ? (venue.free / venue.total).clamp(0.0, 1.0) : null; final ti…`  <sub>:126</sub>

## LibraryController (class)

- `class LibraryController extends ChangeNotifier {` — One library page owns its read snapshots and post-write readback queue.  
  <sub>features/library/library_controller.dart:9</sub>
    - `bool loadingBookings = false, loadingVenues = false, submitting = false;`  <sub>:16</sub>
    - `final Set<String> uncertainActions = {};`  <sub>:17</sub>
    - `bool get busy => loadingBookings \|\| loadingVenues;`  <sub>:22</sub>
    - `void invalidate() => _generation++;` — Drops every in-flight read at its next await: call when the account or  <sub>:27</sub>
    - `Future<void> load({bool force = false}) =>`  <sub>:33</sub>
    - `Future<void> loadVenues({bool force = false}) => _enqueue( force, () => _venueTask, (task) => _venueTask = task, () => _venueForcedRun, (run) => _ven…`  <sub>:86</sub>
    - `Future<void> loadBookings({bool force = false}) => _enqueue( force, () => _bookingTask, (task) => _bookingTask = task, () => _bookingForcedRun, (run)…`  <sub>:116</sub>
    - `Future<void> reservationChanged() async { await _bookingTask; await loadBookings(force: true); }` — A pre-write read must finish before the forced read can be published.  <sub>:148</sub>
    - `Future<void> perform(LibraryBooking booking, String action) async { final key = '${booking.id}/$action'; if (submitting \|\| uncertainActions.contains(…` — The page has already obtained explicit confirmation for this action.  <sub>:154</sub>
    - `void dispose() { _disposed = true; super.dispose(); }`  <sub>:186</sub>

## LibrarySearchField (class)

- `class LibrarySearchField extends StatelessWidget {` — The catalogue search field: one magnifier row with a submit button. The  
  <sub>features/library/library_controls.dart:8</sub>
    - `const LibrarySearchField({ super.key, required this.controller, required this.placeholder, required this.onSubmit, required this.busy, this.boxKey, t…`  <sub>:9</sub>
    - `Widget build(BuildContext context) { final secondary = CupertinoColors.secondaryLabel.resolveFrom(context); return Container( key: boxKey, decoration…`  <sub>:31</sub>

## LibraryFilterField (class)

- `class LibraryFilterField extends StatelessWidget {` — A free-text filter over a list that is already on screen. It filters  
  <sub>features/library/library_controls.dart:80</sub>
    - `const LibraryFilterField({ super.key, required this.placeholder, required this.onChanged, this.filterKey, });`  <sub>:81</sub>
    - `Widget build(BuildContext context) => CupertinoSearchTextField( key: filterKey, placeholder: placeholder, onChanged: onChanged, );`  <sub>:93</sub>

## LibrarySortControl (class)

- `class LibrarySortControl extends StatelessWidget {` — The sort selector of the public catalogue: one segmented control plus a  
  <sub>features/library/library_controls.dart:102</sub>
    - `const LibrarySortControl({ super.key, required this.sort, required this.descending, required this.busy, required this.onSortChanged, required this.on…`  <sub>:103</sub>
    - `Widget build(BuildContext context) => Row( key: rowKey, children: [ Expanded( child: CupertinoSlidingSegmentedControl<String>( key: sortKey, groupVal…`  <sub>:127</sub>

## LibraryPager (class)

- `class LibraryPager extends StatelessWidget {` — The pager of a school-paged list. The current page is always stated in  
  <sub>features/library/library_controls.dart:167</sub>
    - `const LibraryPager({ super.key, required this.page, required this.hasMore, required this.busy, required this.onPrevious, required this.onNext, this.p…`  <sub>:168</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(4, 2, 4, 2), // Wrap, not Row: large-type widths reflow the pager /…`  <sub>:190</sub>

## LibraryPageButtons (class)

- `class LibraryPageButtons extends StatelessWidget {` — The plain previous / next controls of a list that the school pages. The  
  <sub>features/library/library_controls.dart:245</sub>
    - `const LibraryPageButtons({ super.key, required this.canGoPrevious, required this.canGoNext, required this.onPrevious, required this.onNext, this.prev…`  <sub>:246</sub>
    - `Widget build(BuildContext context) { final previous = CupertinoButton( key: previousKey, onPressed: canGoPrevious ? onPrevious : null, child: const T…`  <sub>:269</sub>

## LibraryHistoryPage (class)

- `class LibraryHistoryPage extends StatefulWidget {` — member/seat is a read-only POST. Page failures never advance the cursor.  
  <sub>features/library/library_history_page.dart:12</sub>
    - `const LibraryHistoryPage({super.key, required this.service});`  <sub>:13</sub>
    - `State<LibraryHistoryPage> createState() => _LibraryHistoryPageState();`  <sub>:16</sub>

## LibraryHoldingsPage (class)

- `class LibraryHoldingsPage extends StatefulWidget {` — The copies the school holds for one catalogue record. The status text is  
  <sub>features/library/library_holdings_page.dart:14</sub>
    - `const LibraryHoldingsPage({ super.key, required this.service, required this.bibId, required this.title, });`  <sub>:15</sub>
    - `State<LibraryHoldingsPage> createState() => _LibraryHoldingsPageState();`  <sub>:25</sub>

## LibraryLoansPage (class)

- `class LibraryLoansPage extends StatefulWidget {` — Private records exist only while this page is active. No background reads.  
  <sub>features/library/library_loans_page.dart:12</sub>
    - `const LibraryLoansPage({super.key, this.gateway});`  <sub>:13</sub>
    - `State<LibraryLoansPage> createState() => _LibraryLoansPageState();`  <sub>:16</sub>

## LibraryPage (class)

- `class LibraryPage extends StatefulWidget {` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>features/library/library_page.dart:20</sub>
    - `const LibraryPage({super.key, required this.service});`  <sub>:21</sub>
    - `State<LibraryPage> createState() => _LibraryPageState();`  <sub>:24</sub>

## LibrarySeatPage (class)

- `class LibrarySeatPage extends StatefulWidget {` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>features/library/library_seat_page.dart:18</sub>
    - `const LibrarySeatPage({ super.key, required this.service, required this.area, required this.slot, required this.onReservationChanged, required this.o…`  <sub>:19</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:27</sub>
    - `State<LibrarySeatPage> createState() => _LibrarySeatPageState();`  <sub>:33</sub>

## LibrarySlotPage (class)

- `class LibrarySlotPage extends StatefulWidget {` — Library hierarchy and explicit, single-attempt booking actions.  
  <sub>features/library/library_slot_page.dart:12</sub>
    - `const LibrarySlotPage({ super.key, required this.service, required this.area, required this.onReservationChanged, required this.onViewReservations, }…`  <sub>:13</sub>
    - `final Future<void> Function() onReservationChanged;`  <sub>:20</sub>
    - `State<LibrarySlotPage> createState() => _LibrarySlotPageState();`  <sub>:25</sub>

## CountPair (class)

- `class CountPair {`  
  <sub>features/library/library_stats_models.dart:6</sub>
    - `const CountPair({required this.available, required this.total});`  <sub>:7</sub>

## ReadingRoom (class)

- `class ReadingRoom {`  
  <sub>features/library/library_stats_models.dart:15</sub>

## LibraryCampusStats (class)

- `class LibraryCampusStats {`  
  <sub>features/library/library_stats_models.dart:24</sub>

## LibraryStatsSnapshot (class)

- `class LibraryStatsSnapshot {`  
  <sub>features/library/library_stats_models.dart:46</sub>

## LibraryStatsPage (class)

- `class LibraryStatsPage extends StatefulWidget {` — Public counts are a snapshot, not a promise that a resource is bookable.  
  <sub>features/library/library_stats_page.dart:12</sub>
    - `const LibraryStatsPage({super.key, required this.service});`  <sub>:13</sub>
    - `State<LibraryStatsPage> createState() => _LibraryStatsPageState();`  <sub>:16</sub>

## LibraryPageHeader (class)

- `class LibraryPageHeader extends StatelessWidget {` — The section header every library drill-down page uses. The trailing  
  <sub>features/library/library_widgets.dart:14</sub>
    - `const LibraryPageHeader({ super.key, required this.title, required this.subtitle, required this.icon, this.section = '空间资源', this.refreshLabel, this.…`  <sub>:15</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:32</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), section: section, subtitle: subtitle, icon: icon, border: null, trail…`  <sub>:35</sub>

## LibraryEmptyState (class)

- `class LibraryEmptyState extends StatelessWidget {` — One shared empty / error state for every library list. A failure keeps  
  <sub>features/library/library_widgets.dart:56</sub>
    - `const LibraryEmptyState({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, this.animateSize…`  <sub>:57</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: animateSize, children: [ AppleEmptyState( title: title, description: description, ac…`  <sub>:77</sub>

## LibrarySectionStatus (class)

- `class LibrarySectionStatus extends StatelessWidget {` — Inline status for a section that is still loading or that failed while  
  <sub>features/library/library_widgets.dart:94</sub>
    - `const LibrarySectionStatus({ super.key, required this.id, required this.loading, required this.hasSnapshot, required this.failure, required this.retr…`  <sub>:95</sub>
    - `Widget build(BuildContext context) => AppleListTile( key: Key('library-$id-status'), leading: loading ? const GinkgoActivity(size: 17) : const Icon( …`  <sub>:111</sub>

## LibraryDisclosureToggle (class)

- `class LibraryDisclosureToggle extends StatelessWidget {` — The toggle of a collapsible read-only note. The label states the current  
  <sub>features/library/library_widgets.dart:134</sub>
    - `const LibraryDisclosureToggle({ super.key, required this.label, required this.expanded, required this.onToggle, this.toggleKey, });`  <sub>:135</sub>
    - `Widget build(BuildContext context) { final secondary = CupertinoColors.secondaryLabel.resolveFrom(context); return Align( alignment: Alignment.center…`  <sub>:149</sub>

## LibraryNoteText (class)

- `class LibraryNoteText extends StatelessWidget {` — The body of a read-only note that the reader opened on purpose.  
  <sub>features/library/library_widgets.dart:193</sub>
    - `const LibraryNoteText({super.key, required this.text});`  <sub>:194</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(24, 0, 24, 12), child: Text( text, style: TextStyle( fontSize: 13, …`  <sub>:199</sub>
