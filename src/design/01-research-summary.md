# 01 — สรุปการค้นคว้า

> ที่มา: `Zydraxyl-HUB/Design/eco/research/` ไฟล์ T1-C §3, T2-C §3, T3-C §3, T4-C §1/§4/§6, T5 ทั้งไฟล์
> ระดับความมั่นใจ: sandbox ตอนค้นคว้าเข้าเว็บได้ไม่ครบ — หลายแถวมาจาก snippet ของผลค้นหา (`[S]`)
> หรือความรู้ของ model (`[K]`) ไม่ได้อ่านหน้าจริง (`[V]`) · ข้อที่ไม่ใช่ `[V]` ต้องตรวจก่อนใช้เป็นข้อเท็จจริง

---

## 1. ผลิตภัณฑ์ที่เทียบ

| ชื่อ | URL | licence · stack | ยืมอะไร | ไม่เอาอะไร |
|---|---|---|---|---|
| Calibre | https://manual.calibre-ebook.com/metadata.html · https://manual.calibre-ebook.com/virtual_libraries.html | GPL-3 · Python/Qt · SQLite `metadata.db` + โฟลเดอร์ต่อเล่ม `[K]` | แก้หลายเล่มพร้อมกันบน selection · search/replace รายช่อง (regex + capture group) · virtual library = saved search ที่จำกัดทั้งมุมมอง `[S]` | โฟลเดอร์ต่อเล่ม (QuetzaLib ไม่เก็บไฟล์ ebook) · หน้าต่างแก้ข้อมูลแบบ modal ใหญ่ |
| Tellico (KDE) | https://docs.kde.org/trunk_kf6/en/tellico/tellico/main-window.html · https://tellico-project.org/?p=61 | GPL · C++/Qt · ไฟล์ XML (zip) `[S]` | **Group view** (ต้นไม้จัดกลุ่มตามช่องใดก็ได้ + จำนวน + กลุ่ม "(ว่าง)") · column view ที่ผู้ใช้เลือกคอลัมน์เอง · import/export หลายรูปแบบ `[S]` | ไฟล์ข้อมูล XML แทน DB (QuetzaLib ใช้ SQLite อยู่แล้ว) |
| Libib | https://support.libib.com/support/add-items/ · https://support.libib.com/?p=209 · https://support.libib.com/tags/csv | ปิด · web | สแกนเนอร์พิมพ์ลงช่องที่โฟกัส → ค้น/เพิ่มทันที · กฎ "หนังสือต้องเป็น ISBN, UPC ให้ผลผิด" · batch edit ป้าย เพิ่ม/แทน/ลบ · กฎ CSV (UTF-8, คอลัมน์ id เดียว, รายงานแถวที่ข้าม) `[S]` | ต้องมีบัญชี/คลาวด์ |
| StoryGraph | https://app.thestorygraph.com/wrap-up/2025/junegraphs | ปิด · web | สรุปการอ่านรายปี (ยอดรวม, กราฟรายเดือน, % เป้า) `[S]` | นำเข้า Goodreads ที่ "Date Read" อาจผิด — ถ้าทำต้องมีพรีวิวก่อน `[S]` |
| GCstar · Data Crow · Alexandria | (T1-C §3.2) | GPL · Perl/Java/Ruby `[K]` | template ประเภทคอลเลกชัน | ความอืดของแอป desktop รุ่นเก่า |
| สแกนเนอร์ USB แบบ HID (keyboard-wedge) | https://junipersys.com/support/article/1321 · https://www.cleverence.com/articles/usb-barcode-scanners/how-to-enable-usb-hid-mode-on-zebra-ds457-barcode-scanner | — | พิมพ์ตัวเลขเหมือนคีย์บอร์ด + ลงท้าย Enter · **โฟกัสผิดช่องคือปัญหาอันดับ 1** · guard char แยกการยิงออกจากการพิมพ์ `[S]` | ก๊อปบาร์โค้ดตั้งค่าของยี่ห้อมาใส่ help (ให้ลิงก์ไปคู่มือผู้ผลิตแทน) |
| `sqflite_common_ffi` | https://pub.dev/packages/sqflite_common_ffi | BSD · Dart FFI | SQLite แบบไฟล์จริงบน Windows · เตือนว่า `getDatabasesPath()` นอกมือถือ "lame" → ใช้ path ที่กำหนดเอง `[V via T3-C]` | — |
| `mobile_scanner` | https://pub.dev/documentation/mobile_scanner/latest/ | — | — | ไม่รองรับ Windows/Linux `[S]` |
| `image_picker_windows` | https://pub.dev/packages/image_picker_windows | — | เลือกไฟล์รูปได้ · กล้องต้องมี `cameraDelegate` `[S]` | — |
| `window_manager` / `tray_manager` | https://github.com/leanflutter/window_manager · https://github.com/leanflutter/tray_manager | MIT `[V]` | ไว้ใช้เมื่อจำเป็นต้องมี tray / จำขนาดหน้าต่าง (ไม่อยู่ใน MVP) | — |

---

## 2. ข้อสรุปตามหัวข้อ

### 2.1 โครงสร้าง (T1-C §3, T3-C §3.1)
1. **Flutter Windows จาก `lib/` เดิม ชนะ Electron ห่อ web build** — เหตุผลที่ชี้ขาด: Electron + `sqflite_common_ffi_web`
   เก็บ DB ไว้ใน IndexedDB ของ Chromium (มองไม่เห็นเป็นไฟล์) ส่วน Flutter Windows ใช้ path `_io` ที่มีอยู่แล้ว
   ได้ SQLite + รูปเป็นไฟล์จริง และตรงกฎ "`lib/` เป็น source tree เดียว" ใน `CLAUDE.md` · ขนาด ~25–40 MB vs Electron 100 MB+ `[K]`
2. งานค้นคว้าสองไฟล์ตรงกัน: QuetzaLib-EXE (Electron) กลายเป็นของซ้ำ → ถอด หรือเหลือเป็น repo แพ็กเกจ (owner decision)
3. pattern conditional export (`_io` / `_web`) รองรับ Windows ได้เลย เพราะ Windows ใช้ฝั่ง `_io` —
   แต่ guard วันนี้เป็น `kIsWeb` อย่างเดียว (12 จุดใน 5 ไฟล์) **ไม่มี** `Platform.isAndroid` → บน Windows โค้ดจะเรียก ML Kit
   แล้ว `MissingPluginException` (T3-C §3, ยืนยันจากโค้ด: `ocr_service.dart:32`, `cover_scan_screen.dart:112`, `page_scan_screen.dart:54`, `scan_cover_first_screen.dart:39`)

### 2.2 ฟีเจอร์ (T2-C §3, §4a)
- MVP ที่งานค้นคว้าเลือก 8 ข้อ: bulk edit · search/replace + พรีวิว · ดึง metadata ตาม ISBN · virtual library · saved search ·
  สแกนเนอร์ลงช่องที่โฟกัส · กฎ ISBN vs UPC · เอกสารตั้งค่าสแกนเนอร์
- เอกสารนี้**ย้าย regex ไป v1** (เปิดได้ด้วย toggle) เพราะ forum ของ Calibre เองเตือนให้ลองกับไม่กี่เล่มก่อน — MVP มีพรีวิว diff บังคับแทน → ❓ Q13
- รูปแบบส่งออก Eco: งานค้นคว้าถาม XML vs JSON — **เลือก JSON** เพราะสัญญา Eco (ECO-B2, ECO-E1) เป็น JSON ทั้งหมดแล้ว ไม่ต้องถามเจ้าของ

### 2.3 ระบบภายใน (T3-C §0, §3.2–3.6)
- **X1 id:** ทุกแอปใช้ integer AUTOINCREMENT และ remap ตอนนำเข้า → ต้องเพิ่ม `eid` (UUID) ต่อแถวที่ Eco มองเห็น ไม่แทน PK เดิม
- **X2 สอง process เขียน SQLite:** `LibraryProvider` โหลดครั้งเดียว — ถ้า MCP เปิด DB จากอีก process UI จะค้าง
  → MCP ต้องคุยกับแอปที่รันอยู่ (ซึ่งคือ ECO-C5 พอดี)
- **X4 backup เดิมมีเวอร์ชัน:** `data.json` มี `formatVersion: 1` — แต่ **ตัวอ่านไม่ตรวจค่านี้** (`backup_service.dart` เขียนที่บรรทัด 128 แต่ `importFromZipBytes` ไม่อ่าน) — พบตอนอ่านโค้ด ต้องแก้ตาม ECO-R15 แถว 4
- bulk edit: `authors`/`illustrators` เก็บเป็นสตริงคั่น `|` → แทนที่ต้อง split/join ไม่ใช่ substring · undo 1 ระดับเก็บ pre-image ในหน่วยความจำ
- path DB: `getDatabasesPath()` ไม่น่าเชื่อบน desktop; **และ** `local_image_platform_io.dart` เก็บรูปที่ `getApplicationDocumentsDirectory()`
  ซึ่งบน Windows = โฟลเดอร์ Documents ของผู้ใช้ตรง ๆ (จะได้ `Documents\covers\`, `Documents\pages\`) — พบตอนอ่านโค้ด ต้องย้ายเข้า root ของคลัง

### 2.4 UX (T4-C §4, §1, §6)
- เลย์เอาต์ตาม `UX-LAYOUT.md` ของ DraconDex: ซ้าย = นำทาง (Group view) · กลาง = งาน (รายการ) · ขวา = คุณสมบัติของสิ่งที่เลือก
- bulk edit: ช่องที่ไม่แตะ = **(ไม่เปลี่ยน)** · ค่าต่างกัน = **(หลายค่า)** ต้องเลือกเองจึงเขียนทับ · พรีวิว diff ก่อนกด · เลิกทำได้ทั้งชุด
- เพิ่มด่วน: หน้าจอที่ช่องรับโฟกัสตลอด + ตัวจับ "พิมพ์รัว" (≥ 10 ตัว ห่างกัน < ~50 ms = สแกนเนอร์) เป็นทางสำรอง —
  ค่าเกณฑ์เวลาเป็นสมมติฐาน ต้องวัดกับเครื่องจริง → ❓ Q7
- **ข้อเสนอที่ผมรับมาใช้:** UI พรีวิว diff ของ bulk edit = UI เดียวกับที่ใช้รีวิวข้อเสนอของ Z.I.Z (`eco_apply`) — component เดียว undo เดียว

### 2.5 Eco (T5, ECO-CONTRACT)
- QuetzaLib-APP เป็น root ของ chain ตัวเอง → **รับสัญญา Eco แบบ pull-pin** (ECO-G2) ไม่ใช่ edge
- token: ใช้ `tokens.g.dart` ที่ generator ของ DraconDex สร้างอยู่แล้ว + ตัวสร้าง `ThemeData` (T4-C §4.6) · ต่างได้แค่ accent (ECO-T2)
- MCP: stdio shim → named pipe → แอปที่รันอยู่ (ECO-C4/C5) · ชุด tool มาตรฐาน (ECO-C6) + tool `qzl_*`

---

## 3. ข้อที่งานค้นคว้าขัดกันเอง (เลือกแล้ว)

| เรื่อง | ไฟล์ A | ไฟล์ B | เลือก | เหตุผลหนึ่งบรรทัด |
|---|---|---|---|---|
| โฟลเดอร์ข้อมูลบน Windows | T1-C: `Documents\QuetzaLib\<Library>\` (แบบ Calibre มองเห็นได้) | T3-C: `%APPDATA%\ZYDRAXYL\QuetzaLib\` (Roaming) | `%LOCALAPPDATA%\QuetzaLib\` (❓ Q4) | Roaming ไม่เหมาะกับ SQLite+รูปจำนวนมาก, Documents เสี่ยงโดน OneDrive sync ระหว่าง DB เปิดอยู่ `[K]` · ตรงกับตัวอย่าง DraconDex ใน ECO-L1 (`AppData\Local\DraconDex\…`) |
| `formatVersion` เป็น int | T1-C §5 | ECO-R2 | `"MAJOR.MINOR"` | สัญญา Eco ชนะ |
| ชื่อ tool MCP | T3-C: `qzl.search_books` | ECO-C8: `<code>_` | `qzl_*` | สัญญา Eco ชนะ |
| เติม `uid` แบบ lazy ตอนส่งออกครั้งแรก | T3-C X1 | — | เติมทันทีตอน migrate v9 | คลังมีหลักพันเล่ม เติมครั้งเดียวจบ ไม่ต้องมีโค้ดสองทาง |
| UUID v4 | T3-C X1 | ECO-I4 (v7) | v7 | สัญญา Eco ชนะ |
