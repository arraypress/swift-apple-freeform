# Swift Apple Freeform

Read Apple Freeform from Swift — boards, and what is written on them: text boxes, sticky
notes, table cells, links, pictures and files — by reading Freeform's store, not by
driving the app.

```swift
import AppleFreeform

let store = try FreeformStore()
for board in store.boards() { print(board.name, board.itemCount) }
let plan = try store.board("Kitchen plan")
for item in store.items(board: plan.id) { print(item.kind, item.text, item.url ?? "", item.file?.path ?? "") }
store.search("tiles")              // every live board's words and links
```

## Where Freeform keeps it, and what is there

Measured on macOS 27 with a board made for the purpose:

- **The store** is a SQLite file, `~/Library/Group Containers/group.com.apple.freeform/Boards/boards.db`;
  pictures and files sit in `Assets/` beside it, as `<asset id>.<extension>`, found through
  `asset_references` (a picture's `image`, not its `thumbnail`). Not encrypted on the Mac; the
  container is protected, so the app reading it needs Full Disk Access. Opened read-only.
- **Every item is a sync record**: `crdt`, a version, then a protobuf. Unlike Journal's records,
  the trailing string table holds only keys (`a`, `b`…); the words sit as string values in
  nested messages. `RecordStrings` walks the protobuf: printable text with letters or digits
  is text, a value that parses as a message is walked into, and keys, font names
  (`com.apple.Freeform.system.font…`), attribute names and single characters are left out.
  On the test board every text box, sticky note, table cell, link and file name came out,
  and nothing else.
- **Item types** (as measured): 2 shape, 2/1 table (its cells are in the larger `capsule_data`
  record), 3 text box, 4 connector, 5 picture or file, 8 link, 12 sticky note. Anything else
  is `.other`, its words still read.
- **Not read**: where things sit on the board, sizes, colours, connector paths. A table's cells
  come in the order Freeform stores them, which is not the grid's — said in the docs and
  the output rather than guessed.
- **Deleted** boards and removed items are left out unless asked; a live asset's
  `tombstone_date` is `0`, not empty (the first reading missed every picture until this was
  measured).

## Writing

Nothing here writes. Freeform's Shortcuts actions can create, open, rename and delete boards
and add files to one — not text or sticky notes. Writing to the store directly would bypass
iCloud's sync — never.

## Tested

6 tests against a synthetic store with Freeform's tables and records built the way its are —
no one's board is read. Every rule broken on purpose is caught (11 of 11 mutations).

## Requirements

macOS 14 or later; Swift 6.2. Full Disk Access for the app reading it.

## License

MIT — see [LICENSE](LICENSE).
