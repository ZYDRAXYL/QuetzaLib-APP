# 04 — ระบบภายใน

## 1. ที่เก็บคลังบน Windows — `library_paths.dart`

| แพลตฟอร์ม | DB | รูป | ที่มา |
|---|---|---|---|
| Android | `getDatabasesPath()/quetzalib.db` (เดิม) | `getApplicationDocumentsDirectory()/covers|pages` (เดิม) | ไม่เปลี่ยน |
| web | IndexedDB (เดิม) | ตาราง `local_images` (เดิม) | ไม่เปลี่ยน |
| **Windows** | `%LOCALAPPDATA%\QuetzaLib\library\quetzalib.db` | `%LOCALAPPDATA%\QuetzaLib\library\covers\` · `pages\` | ใหม่ |

```
%LOCALAPPDATA%\QuetzaLib\
├── library\
│   ├── quetzalib.db (+ -wal/-shm)
│   ├── covers\  pages\
│   └── snapshots\<yyyyMMdd-HHmmss>-<proposalId|manual>.db    ← ECO-S3
└── logs\
```

- ได้ path จาก `Platform.environment['LOCALAPPDATA']` (stdlib) — `path_provider` บน Windows ให้ Roaming (`getApplicationSupportDirectory`)
  หรือ Documents ซึ่งไม่ต้องการ
- **ทำไมไม่ Roaming:** profile แบบ roaming copy ไฟล์ตอน logon/logoff — SQLite ที่เปิดอยู่ + รูปหลักพันไฟล์ไม่เหมาะ `[K]` · ECO-L1 ใช้ Local ด้วยเหตุผลเดียวกัน
- **ทำไมไม่ Documents:** Windows 10/11 มักย้าย Documents เข้า OneDrive (Known Folder Move) — sync ไฟล์ `-wal` ระหว่าง DB เปิดอยู่เสี่ยงข้อมูลเสีย `[K]`
- มองเห็นได้ด้วยปุ่ม **"เปิดโฟลเดอร์คลัง"** ใน Settings · locator ชี้มาที่นี่ (06 §3)
- ไม่ใช้ `%LOCALAPPDATA%\Zydraxyl\` เพราะ Windows ไม่แยกตัวพิมพ์ — `ZYDRAXYL` = `Zydraxyl` = โฟลเดอร์ของ Hub (`locator\`, `apps\` — ECO-L1) ข้อมูลแอปไม่ควรปนกับของ Hub
- `local_image_platform_io.dart` ต้องรับ root จาก `library_paths.dart` แทน `getApplicationDocumentsDirectory()` เฉพาะ Windows
  (ไม่งั้นได้ `Documents\covers\`) · path รูปยังเก็บเป็น absolute เหมือน Android —
  `ponytail: absolute path ผูกกับเครื่อง; ถ้าทำ "ย้ายที่เก็บคลัง" (F52) ต้องเขียน path ใหม่ทั้งตาราง หรือเปลี่ยนเป็น relative ตอนนั้น`
- ❓ รอเจ้าของตัดสิน → Grill Q4

## 2. Schema v9 (`_dbVersion` 8 → 9)

ตารางวันนี้ (ยืนยันจาก `database_service.dart`): `books` · `categories` (name UNIQUE) · `book_categories` · `reading_stamps` ·
`book_cover_presets` · `book_pages` · `local_images` (web เท่านั้น) · `name_alias_groups`

```sql
-- _migrateToV9 — เพิ่มอย่างเดียว ไม่ลบ ไม่ rename (แบบเดียวกับ v3–v8)
ALTER TABLE books              ADD COLUMN eid TEXT;
ALTER TABLE books              ADD COLUMN updatedAt TEXT;      -- ISO-8601 UTC 'Z' (ECO-R10)
ALTER TABLE categories         ADD COLUMN eid TEXT;
ALTER TABLE reading_stamps     ADD COLUMN eid TEXT;
ALTER TABLE book_cover_presets ADD COLUMN eid TEXT;
ALTER TABLE book_pages         ADD COLUMN eid TEXT;
ALTER TABLE name_alias_groups  ADD COLUMN eid TEXT;
-- backfill: Dart วนทุกแถว ใส่ UUIDv7 ใหม่ · books.updatedAt = dateAdded (ใน transaction เดียว)
CREATE UNIQUE INDEX idx_books_eid      ON books(eid);
CREATE UNIQUE INDEX idx_categories_eid ON categories(eid);
CREATE UNIQUE INDEX idx_stamps_eid     ON reading_stamps(eid);
CREATE UNIQUE INDEX idx_presets_eid    ON book_cover_presets(eid);
CREATE UNIQUE INDEX idx_pages_eid      ON book_pages(eid);
CREATE UNIQUE INDEX idx_alias_eid      ON name_alias_groups(eid);

CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- 'libraryUid' = projectUid ของคลัง (UUIDv7, ห้ามเปลี่ยน — ECO-I4) · 'libraryName' = 'คลังของฉัน'

CREATE TABLE saved_searches (               -- F17
  id INTEGER PRIMARY KEY AUTOINCREMENT, eid TEXT UNIQUE,
  name TEXT NOT NULL, query TEXT NOT NULL,  -- JSON {q, status, categoryEids[], field filters}
  createdAt TEXT NOT NULL
);

CREATE TABLE eco_grants (                   -- ECO-S1 (Windows เท่านั้นที่ใช้)
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client TEXT NOT NULL,                     -- ชื่อจาก MCP initialize — ป้ายเท่านั้น ปลอมได้
  level TEXT NOT NULL,                      -- read | propose | write | delete
  batch INTEGER NOT NULL DEFAULT 0,         -- 1 = apply ไม่ต้องกดทีละครั้ง (ECO-S2)
  grantedAt TEXT NOT NULL, expiresAt TEXT   -- NULL = จบ session ❓ ECO-S1 N วัน
);

CREATE TABLE eco_audit (                    -- ECO-S4 append-only
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  at TEXT NOT NULL, client TEXT NOT NULL, tool TEXT NOT NULL,
  proposalId TEXT, eids TEXT,               -- JSON array
  snapshot TEXT, result TEXT NOT NULL       -- applied | rejected | denied | error:<msg>
);
```

- `eid` เขียนใน `onCreate` ด้วย (DB ใหม่) · `Book.toMap/fromMap` และ model อื่นได้ฟิลด์ `eid` · ทุก `updateBook` ตั้ง `updatedAt`
- ทุกแพลตฟอร์มได้ v9 พร้อมกัน (lib/ เดียว) — Android จึงส่งออก `.zeco` ที่มี `eid` ได้ด้วย ซึ่งจำเป็นต่อการย้ายข้อมูล (§5)
- `seriesVolume`: `onCreate` ประกาศ `REAL` แต่ `_migrateToV5` ใส่ `INTEGER` — SQLite ไม่สนใจ (type affinity) codec อ่านเป็น `num` เสมอ
- `book_categories` ไม่ต้องมี `eid` (เป็นแค่ link) · `local_images` ไม่ต้อง (เก็บรูปของ web)

## 3. ปฏิเสธ DB ที่ใหม่กว่าแอป (ECO-K7)

Hub ติดตั้งหลายเวอร์ชันคู่กัน (ECO-K7) ทุกเวอร์ชันเปิดโฟลเดอร์เดียวกัน (§1) → QuetzaLib 1.14 อาจเจอ DB v10 ของ 1.15
- เพิ่ม `onDowngrade` ใน `openDatabase` ที่ **throw `DatabaseTooNewException(found, known)`** → แอปแสดงหน้าจอ
  "คลังนี้สร้างด้วย QuetzaLib เวอร์ชันใหม่กว่า — เปิดด้วยเวอร์ชันล่าสุดผ่าน Hub" + ปุ่มเปิดโฟลเดอร์ (ไม่มีโหมดอ่านอย่างเดียวใน MVP —
  `ponytail: เปิด read-only ต้องมี path ที่ไม่เขียนเลยทั้งแอป เพิ่มเมื่อมีคนต้องการจริง`)
- ⚠ **ต้องตรวจ:** พฤติกรรมของ sqflite เมื่อไม่มี `onDowngrade` — ถ้ามันตั้ง `user_version` ลงเป็นค่าต่ำ แล้วเวอร์ชันใหม่เปิดอีกครั้งจะรัน
  `ALTER TABLE ADD COLUMN` ซ้ำจน error · การมี `onDowngrade` ที่ throw ป้องกันทั้งสองกรณี
- exit code ตอนเปิดผ่าน Hub: `12` = โปรเจกต์ใหม่กว่าแอปนี้ (ECO-C3)

## 4. รูปแบบ `qzl.library` 1.0 (ร่าง — QuetzaLib เป็นเจ้าของตาม ECO-I3, ECO-G4)

อยู่ใน `.zeco` เป็น part `primary` (ECO-B3) ที่ `parts/library/library.json` + part `eco.entity-set` (role `data` — **ต้อง** เพราะ Z.I.Z อ่าน, ECO-R9)
รูปอยู่ใต้ `assets/<sha256>/<ชื่อเดิม>` (ECO-R13)

```json
{
  "format": "qzl.library", "formatVersion": "1.0",
  "library": {"uid": "0192f3a0-aaaa-7bbb-8ccc-000000000001", "name": "คลังของฉัน"},
  "scope": "all",
  "categories": [{"eid": "0192…c1", "name": "Comics & Manga", "color": "#6750A4"}],
  "nameSets": [{"eid": "0192…n1", "terms": ["TH", "thai", "ไทย"]}],
  "books": [{
    "eid": "0192…b1",
    "isbn13": "9784048…", "isbn10": null,
    "title": "Overlord 3",
    "authors": ["Kugane Maruyama"], "illustrators": ["so-bin"],
    "series": "Overlord", "seriesVolume": "3",
    "genre": "นิยาย", "publisher": "KADOKAWA", "publishedDate": "2013-04-30",
    "description": "…", "pageCount": 384, "language": "ja", "rating": 4, "notes": "…",
    "source": "google_books", "thumbnailUrl": "https://books.google.com/…",
    "dateAdded": "2026-01-03T10:00:00Z", "updatedAt": "2026-10-18T09:00:00Z",
    "categories": ["0192…c1"],
    "stamps": [{"eid": "0192…s1", "type": "reading", "at": "2026-10-01T12:00:00Z", "note": null}],
    "covers": [{"eid": "0192…p1", "label": "ปกพิมพ์แรก", "active": true,
                "front": "assets/9f2b…/front.jpg", "spine": null, "back": null, "createdAt": "…Z"}],
    "pages": [{"eid": "0192…g1", "image": "assets/1c3d…/p12.jpg", "label": "หน้า 12", "note": "ฉากโปรด", "createdAt": "…Z"}]
  }]
}
```

กติกา schema (ทำตาม §5–§8 ของสัญญา):

| ฟิลด์ | กฎ |
|---|---|
| บังคับ | `format` `formatVersion` `library.uid` `books[].eid` `books[].title` — อย่างอื่น optional (ECO-R5) |
| `authors` `illustrators` | **array** — DB เก็บคั่น `|` codec split/join (ไม่ส่ง `|` ออกนอกแอป) |
| `seriesVolume` | string ทศนิยม (`"3"`, `"3.5"`) ตาม ECO-R10 |
| `color` | `#RRGGBB` (DB เก็บ int ARGB) |
| `stamps[].type` | **open enum** `reading|finished|dropped|paused` · `fallback: "unknown"` = แสดงในไทม์ไลน์เป็น "อื่น ๆ" และไม่นับตอนคำนวณสถานะปัจจุบัน (ECO-R6) |
| `scope` | open enum `all|selection` · fallback `selection` (นำเข้าแบบรวมเสมอ) |
| `thumbnailUrl` | ฟิลด์เดียวที่ประกาศเป็น URL (ECO-R11) |
| ห้ามมี | Cloud Vision key, ค่าใน `shared_preferences`, path absolute, `id` integer (อาจมี `localId` เพื่อ debug — ECO-I4) |
| ฟิลด์ไม่รู้จัก | ข้าม (ECO-R14) · QuetzaLib อ่านไฟล์ของตัวเองจากเวอร์ชันใหม่กว่าแล้วส่งออกซ้ำ **ควร**เก็บไว้ (ECO-R20) — v1: เก็บไว้ในคอลัมน์ไม่ได้ จึงไม่ทำ, ระบุใน CHANGELOG |
| JSON Schema | draft 2020-12 · **ไม่มี** `additionalProperties:false` (ECO-R29) · `reserved` list ว่าง |

`minReader` = `"1.0"` จนกว่าจะมี minor ที่ผู้อ่านต้องรู้จัก (ECO-R7)

**mapping → `eco.entity-set`** (สำหรับ Z.I.Z / Hub / DraconDex):
`kind:"book"` · `name` = title · `summary` = `"<authors> · <series> #<vol>"` · `tags` = ชื่อหมวด ·
`fields` = `{isbn13, authors[], series, seriesVolume, status, rating, language, genre, publisher, pageCount}` (ชั้นเดียวตาม ECO-E1) ·
`text` = `notes` เป็น `eco.text` · `updatedAt`

## 5. มือถือ ↔ PC

| ทาง | MVP? | พฤติกรรม |
|---|---|---|
| `.zip` สำรองเดิม (`data.json formatVersion 1`) | นำเข้าได้ · **ไม่ส่งออกใหม่** | แทนที่ทั้งคลัง (เหมือนเดิม) · เพิ่มการตรวจ: `formatVersion` ไม่ใช่ 1 → ปฏิเสธ (วันนี้ไม่ตรวจ) · แถวที่ไม่มี `eid` ได้ `eid` ใหม่ตอนนำเข้า |
| **`.zeco` (`qzl.library`)** | ✅ | ส่งออก: ทั้งคลัง / ที่เลือก · นำเข้า: **รวม** ตามตารางล่าง — ใช้ได้ทั้งบนมือถือและ PC เพราะ `lib/` เดียว |
| โฟลเดอร์ sync ไฟล์ต่ออุปกรณ์ | later (F51) | ต้องมี `deletedAt` (tombstone) ทุกตาราง |

**การรวม (merge) ตอนนำเข้า `.zeco`** — atomic ใน transaction เดียว (ECO-R17) · พรีวิวก่อนเสมอ และขั้นนำเข้าอ่านไฟล์ใหม่เอง (ECO-R16)

| สิ่งที่เจอ | ทำ |
|---|---|
| book `eid` ใหม่ | เพิ่ม — แต่ถ้า ISBN13 ตรงกับเล่มที่มี (eid ต่างกัน) → ขึ้นในพรีวิวเป็น "อาจซ้ำ" ให้เลือก รวม / เพิ่มแยก |
| book `eid` มีแล้ว | ถามครั้งเดียวต่อการนำเข้า (ECO-R19): **อัปเดตของเดิม** (เฉพาะที่ `updatedAt` ในไฟล์ใหม่กว่า) / **เก็บทั้งคู่** (ออก `eid` ใหม่ให้ฉบับที่นำเข้า) / **ยกเลิก** |
| stamp / cover / page | union ตาม `eid` (ไทม์ไลน์สองเครื่องรวมกันได้โดยไม่ซ้ำ) |
| category | ตาม `eid` → ถ้าไม่มี ตามชื่อ (คอลัมน์ `name` UNIQUE) → ไม่มีทั้งคู่ = เพิ่ม |
| name set | union ตาม `eid` |
| asset | ตรวจ sha256 ก่อนเขียน (ECO-S8) · `quality:none` = ไม่มีรูป ข้าม |

ข้อจำกัดที่บอกผู้ใช้ตรง ๆ: **การลบไม่ตามไป** (ลบบน PC แล้วนำเข้าไฟล์จากมือถือ เล่มนั้นกลับมา) — แก้ด้วย F51
แนะนำ flow แรก: PC เครื่องใหม่ → "นำเข้าจากมือถือ" ไฟล์ `.zeco` หรือ `.zip` → `eid` ตรงกันทั้งสองเครื่องตั้งแต่ต้น · ❓ Q3

## 6. Bulk edit (F14) — `state/library_bulk.dart`

```dart
// pure: ไม่มี Flutter import
sealed class BulkOp {}                         // SetField · ClearField · Replace · AddCategory · RemoveCategory · AddStamp
class BulkPatch { final Set<int> bookIds; final List<BulkOp> ops; }
class BookChange { final int bookId; final Map<String, (Object?, Object?)> fields; /* ก่อน, หลัง */ }
List<BookChange> diff(BulkPatch p, Map<int, Book> books, Map<int, List<int>> cats);   // ใช้ทั้ง UI และ MCP
```

- `LibraryProvider`: `Set<int> selectedIds` · `applyBulk(BulkPatch)` = 1 transaction + 1 `notifyListeners()` · เก็บ pre-image ของรอบล่าสุดในหน่วยความจำ → `undoLastBulk()` (1 ระดับ ไม่มี schema)
- `Replace` บน `authors`/`illustrators`: split `|` → แทนทีละชื่อแบบตรงทั้งคำ → join · ช่องอื่นแทน substring
- ไม่มีเพดานจำนวนเล่มใน UI (ผู้ใช้เห็นพรีวิว) · ผ่าน MCP ≤ 500 ต่อ proposal (ECO-S10)
- ชื่อเรื่อง: op บน `title` ต้องมี `confirmTitle: true` (ยืนยันซ้ำใน UI)

## 7. MCP ภายใน (สรุป — รายการ tool ที่ 06 §2)

| ส่วน | ทำอะไร |
|---|---|
| `mcp/server.dart` | JSON-RPC 2.0 บรรทัดละข้อความ: `initialize` · `tools/list` · `tools/call` · `resources/list` · `resources/read` — เขียนเอง ไม่เพิ่ม SDK (`dart_mcp` ยัง experimental, `mcp_dart` = dep ใหม่ — T3-C §3.6) |
| proposal | `eco_propose` เก็บ `{proposalId, client, BulkPatch|NewBooks, diff}` ในหน่วยความจำ หมดอายุเมื่อแอปปิด |
| snapshot | ก่อน apply ครั้งแรกของ session: `VACUUM INTO '<root>\snapshots\….db'` (ไม่รวมรูป — tool ไม่แตะรูปใน v1) · เก็บ 10 ล่าสุด · ปุ่ม "ย้อนการเปลี่ยนแปลงจาก AI ครั้งนี้" = ปิด DB → copy snapshot ทับ → `loadAll()` |
| audit | แถวใน `eco_audit` ทุก tool call ที่ต้องมีสิทธิ์ (ECO-S4) · ดูได้ใน Settings → การเชื่อมต่อ Eco |

## 8. การทดสอบ (เพิ่มจากชุดเดิมใน `test/`)

| เทสต์ | ไฟล์ |
|---|---|
| migrate v8 → v9 เติม `eid` ครบ ไม่ซ้ำ · DB v10 → `DatabaseTooNewException` | `test/services/database_migration_test.dart` (ใช้ `sqflite_common_ffi` in-memory) |
| codec round-trip: export → import ลงคลังเปล่า → export ซ้ำ ได้ `eid` เดิม (ECO-R8) | `test/eco/qzl_library_codec_test.dart` |
| fixture ของสัญญาทุกตัวใน `reads` นำเข้าได้ · ไฟล์ "ใหม่กว่า" ถูกปฏิเสธตาม ECO-R15 | `test/eco/conformance_test.dart` (ECO-R30) |
| `diff()` ของ bulk: ชื่อผู้แต่งคั่น `|`, ช่องหลายค่า, undo | `test/state/library_bulk_test.dart` |
| zip-slip / sha256 ผิด → ปฏิเสธทั้งไฟล์ | `test/eco/zeco_test.dart` |
| `.zip` เดิม `formatVersion: 2` → ปฏิเสธ | `test/services/backup_service_test.dart` |
