# 02 — สถาปัตยกรรม

## 1. Stack — Flutter Windows desktop จาก `lib/` เดิม

| ชั้น | ของ | หมายเหตุ |
|---|---|---|
| UI | Flutter (Material 3) + `provider` | เหมือนเดิม · เพิ่ม `windows/` ด้วย `flutter create --platforms=windows .` |
| state | `LibraryProvider` ตัวเดียว (ChangeNotifier) | กฎ `CLAUDE.md`: ห้ามมี notifier ตัวที่สอง |
| DB | SQLite ไฟล์จริงผ่าน `sqflite_common_ffi` + `sqlite3_flutter_libs` (Windows) · `sqflite` (Android) · `sqflite_common_ffi_web` (web) | API เดียวกัน เปลี่ยนแค่ `databaseFactory` ตอนเปิด |
| native (Windows) | C++ ใน `windows/runner/` | single instance · named pipe server · รับไฟล์ที่ลากมาวาง — คุยกับ Dart ผ่าน MethodChannel `quetzalib/eco` (pattern เดียวกับ `quetzalib/apk_installer` ใน `MainActivity.kt`) |
| MCP shim | `bin/qzl_mcp_shim.dart` → `dart compile exe` → `quetzalib-mcp.exe` | ไม่มี logic: ส่งต่อไบต์ stdio ↔ pipe เท่านั้น (ECO-C5) |

### 1.1 ทำไมไม่ Electron (QuetzaLib-EXE ตามแผนเดิม)

| เกณฑ์ | Electron ห่อ `flutter build web` | **Flutter Windows** |
|---|---|---|
| DB | SQLite wasm ใน IndexedDB ของ Chromium — ไม่เป็นไฟล์ | `quetzalib.db` เป็นไฟล์ |
| รูปปก/หน้า | blob `webimg://` ในตาราง `local_images` | ไฟล์จริง (โค้ด `_io` มีแล้ว) |
| MCP / locator | ต้องสร้างสะพาน Node ↔ wasm DB | แอปเปิด DB เอง เป็นผู้เขียนคนเดียว (ECO-C5) |
| กฎ "source tree เดียว" | build ของ web + repo ที่สอง | ตรงตัว |
| ขนาด | 100 MB+ `[K]` | 25–40 MB `[K]` |
| สิ่งที่เสีย | — | กล้องใน Chromium (`getUserMedia` + `BarcodeDetector`) ทำได้ง่ายกว่า · ตาราง/แผงย่อขยายเขียนง่ายกว่าใน web |

ที่มา: `Zydraxyl-HUB/Design/eco/research/T1-C-structure.md` §3.3, `T3-C-internals.md` §3.1 · ❓ รอเจ้าของตัดสิน → Grill Q1

---

## 2. Process model

```
┌──────────────── เครื่องผู้ใช้ (Windows) ─────────────────────────────────────────┐
│                                                                              │
│  QuetzaLib.exe (Flutter, หน้าต่างเดียว)                                        │
│   ├─ Dart: LibraryProvider ─► DatabaseService ─► %LOCALAPPDATA%\QuetzaLib\   │
│   │        └─ lib/eco/mcp  (จัดการ JSON-RPC ของ MCP, สิทธิ์, snapshot, audit) │
│   └─ C++ runner: mutex single-instance · \\.\pipe\zydraxyl-quetzalib-<SID>   │
│                  · WM_DROPFILES  ──MethodChannel 'quetzalib/eco'──► Dart      │
│        ▲ pipe (บรรทัดแรก = token จาก instances\quetzalib.token)              │
│        │                                                                     │
│  quetzalib-mcp.exe  ◄── stdio ──  CLI agent ของผู้ใช้ (ผ่าน Z.I.Z)             │
│        (ไม่เปิด DB · แอปไม่รัน → สั่งเปิดแบบย่อ แล้วรอ pipe ≤ 20 วิ — ECO-C5)  │
│                                                                              │
│  %LOCALAPPDATA%\Zydraxyl\locator\quetzalib.json   ← แอปเขียน (ECO-L1/L2)    │
│  %LOCALAPPDATA%\Zydraxyl\instances\quetzalib.json ← มีเฉพาะตอนรัน (ECO-L5)  │
│  Hub ─ argv --eco-open … ─► QuetzaLib.exe (ECO-C3) — ตัวที่รันอยู่รับต่อ (ECO-C11) │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **ผู้เขียน DB มีคนเดียว** = process GUI → ไม่มีปัญหา T3-C X2 (UI ค้างเมื่ออีก process เขียน)
- **ไม่มี listener บนเครือข่าย** (ECO-S7) — named pipe มี DACL ผู้ใช้ปัจจุบัน + `PIPE_REJECT_REMOTE_CLIENTS` + `FILE_FLAG_FIRST_PIPE_INSTANCE`
- pipe server อยู่ใน C++ เพราะ `dart:io` สร้าง named pipe server ไม่ได้ และการตั้ง DACL ต้องเรียก Win32 ตรง
  (ทางเลือก `package:win32` ผ่าน FFI = dependency ใหม่ + isolate บล็อกรอ `ConnectNamedPipe` — แพงกว่า)
- shim เปิด pipe ฝั่ง client ผ่าน `File(r'\\.\pipe\…').open()` ของ `dart:io` — **ยังไม่ได้ทดสอบ**;
  ถ้าใช้ไม่ได้ เขียน shim เป็น C++ ~150 บรรทัดแทน (logic เท่าเดิม: copy ไบต์สองทิศ)

---

## 3. Plugin ที่พังบน Windows และของแทน

ยืนยันจาก `pubspec.yaml` (version `1.13.0+19`) + T3-C §3.2

| package | Windows | แทนด้วย | ฟีเจอร์ที่ผู้ใช้เห็น |
|---|---|---|---|
| `sqflite` | ❌ | `sqflite_common_ffi` + `sqlite3_flutter_libs` (`databaseFactory = databaseFactoryFfi` เมื่อ `Platform.isWindows`) | เหมือนเดิม |
| `mobile_scanner` | ❌ | **USB scanner แบบ keyboard-wedge** + พิมพ์/วาง ISBN (`isbn_entry_screen.dart` มีแล้ว) · webcam = later (❓ Q7) | หน้า "เพิ่มด่วน" ([05](./05-ux-ui.md) §4) |
| `google_mlkit_document_scanner` | ❌ | เลือกไฟล์รูป / ลากรูปจาก Explorer มาวางที่ช่องปก | ไม่มีตัดขอบอัตโนมัติ |
| `google_mlkit_text_recognition` | ❌ | **Cloud Vision เท่านั้น** (ทางเดียวกับ web ใน `ocr_service.dart`) — ไม่มีคีย์ = ซ่อนปุ่ม "สแกนเติมข้อมูล" (❓ Q8) | ต้องใส่ API key ใน Settings |
| `image_picker` | ⚠ เลือกไฟล์ได้ กล้องไม่ได้ | ใช้โหมดเลือกไฟล์ | — |
| `permission_handler` | ไม่ต้องใช้ | guard ด้วย caps | — |
| `apk_installer.dart` + ส่วนดาวน์โหลด APK ใน `update_service.dart` | ❌ ไม่มีความหมาย | **Hub/WEB ดูแลการอัปเดต** (ECO-K1, ECO-K4) · แอปยังเช็ก release ได้ แต่แค่แจ้ง + ปุ่ม "เปิด Hub" / "ไปหน้าดาวน์โหลด" | ส่วนอัปเดตใน Settings |
| `file_picker` `path_provider` `shared_preferences` `package_info_plus` `http` `archive` `provider` | ✅ | — | — |
| `flutter_launcher_icons` | เพิ่ม `windows:` | — | ไอคอน .ico |

**กลไก guard (ไฟล์ใหม่ไฟล์เดียว):** `lib/services/platform_caps.dart`

```dart
// ponytail: getter 3 ตัวแทน if (!kIsWeb) ที่กระจาย 12 จุด — เพิ่ม getter เมื่อมีแพลตฟอร์มใหม่จริง
abstract final class Caps {
  static bool get mobileCamera => !kIsWeb && (Platform.isAndroid || Platform.isIOS); // mobile_scanner, ML Kit, doc scanner
  static bool get apkInstall  => !kIsWeb && Platform.isAndroid;
  static bool get desktop     => !kIsWeb && Platform.isWindows;
}
```
(`dart:io` import บน web พัง — ไฟล์นี้จึงต้องเป็นคู่ conditional export `_io`/`_web` แบบเดียวกับ `local_image_platform*.dart`)
`app_update_section_io.dart` แยกเป็นสองทางด้วย `Caps.apkInstall`

---

## 4. ชั้นของโค้ด (ไม่เปลี่ยนจากเดิม + โฟลเดอร์ `eco/`)

```
screens/ (+ screens/desktop/) ─► state/LibraryProvider ─► services/ ─► sqflite(ffi)
                                       ▲
lib/eco/ (export/import .zeco, locator, MCP) ──┘  รับ provider เป็น constructor arg — ไม่ใช่ notifier ตัวที่สอง
```

กฎ:
1. `lib/eco/` เรียก `LibraryProvider` เพื่อเขียน (UI อัปเดตสด) — **ห้าม**เรียก `DatabaseService` ตรงเพื่อเขียน
2. ฟังก์ชัน pure (สร้าง diff, map `qzl.library` ⇄ model) แยกไฟล์ ไม่มี Flutter import → เทสต์ได้ด้วย `flutter test` ล้วน
3. `library_provider.dart` วันนี้ 714 บรรทัด (เกินแถบ 700+ ของ `quetzalib-file-arch`) — selection + bulk ops ใหม่**ต้อง**ไปอยู่ไฟล์ pure `state/library_bulk.dart`
   ให้ provider เหลือแค่ถือ state + เรียก + `notifyListeners()`

---

## 5. โครงโฟลเดอร์ที่เสนอ

```
QuetzaLib-APP/
├── windows/                         ใหม่ · flutter create --platforms=windows
│   └── runner/eco_bridge.{h,cpp}    ใหม่ · single instance + pipe + drop → MethodChannel
├── bin/qzl_mcp_shim.dart            ใหม่ · → quetzalib-mcp.exe (dart:io เท่านั้น)
├── eco/                             ใหม่ · ของที่ vendor จากสัญญา (ECO-R32) — ห้ามแก้มือ
│   ├── eco.lock.json
│   ├── schemas/  (eco.bundle, eco.entity-set, eco.locator, qzl.library ที่ publish แล้ว)
│   └── fixtures/ (เฉพาะ format ที่ประกาศใน reads)
├── lib/
│   ├── services/platform_caps{,_io,_web}.dart   ใหม่
│   ├── services/library_paths.dart              ใหม่ · root ของคลังต่อแพลตฟอร์ม (04 §1)
│   ├── state/library_bulk.dart                  ใหม่ · pure: BulkPatch → BulkDiff
│   ├── eco/
│   │   ├── tokens.g.dart            vendored (ECO-T3) — generate เท่านั้น
│   │   ├── eco_theme.dart           ThemeData จาก DdxPalette (05 §6)
│   │   ├── uuid7.dart               ~15 บรรทัด, Random.secure — ไม่เพิ่ม package uuid
│   │   ├── zeco.dart                อ่าน/เขียน zip ตาม ECO-B2 (ใช้ `archive` ที่มีอยู่)
│   │   ├── qzl_library_codec.dart   qzl.library 1.0 ⇄ models (pure)
│   │   ├── entity_set.dart          books ⇄ eco.entity-set (pure)
│   │   ├── rendition_html.dart      index.html + README.md (ECO-R9)
│   │   ├── locator.dart             locator + instance + token
│   │   ├── eco_channel.dart         MethodChannel 'quetzalib/eco'
│   │   └── mcp/ server.dart · tools.dart · grants.dart · audit.dart · snapshot.dart
│   └── screens/desktop/ desktop_shell.dart · quick_add_screen.dart · bulk_edit_panel.dart · review_queue.dart · eco_settings_page.dart
├── tools/eco-contract.mjs           vendored · APP เท่านั้น (ไม่ใส่ใน MIRROR_SETS)
└── src/design/                      เอกสารชุดนี้
```

**ไม่มี DraconDex module ถูกคัดลอกมา** — QuetzaLib รับจาก DraconDex แค่ token (ผ่านสัญญา Eco, byte-identical + lock ตาม ECO-R32)
ไม่มีโค้ด DraconDex ให้ต้อง sync

---

## 6. ผลต่อ chain ของ QuetzaLib (`chain/chain.json`)

วันนี้: `desktop APP > EXE > WEB` · EXE = Electron ห่อ web build · release `exe-v*` · มี edge `APP→EXE` (claude-tooling, app-source) และ `EXE→WEB` (release-mirror)
**ในเครื่องนี้ไม่มี clone ของ QuetzaLib-EXE** และ `chain/README.md` §4 บอกว่ามีแค่ `claude-tooling` ที่ทำงานจริง — Electron shell จึงยังไม่มีโค้ดให้ทิ้ง

ข้อเสนอ (ทำผ่าน chain tooling — **ไม่แก้ `chain.json` ด้วยมือ** และเอกสารนี้ไม่ได้แก้) — ❓ Q10:

```diff
 "APP": { "owns": [".claude/", "chain/", "tools/", "docs/", "lib/", "android/", "web/", "test/", "pubspec.yaml",
+                  "windows/", "bin/", "eco/", "src/"] }
- "EXE": { … "releases": "exe-v*" … }
 "chains": {
   "android": ["APP", "WEB"],
-  "desktop": ["APP", "EXE", "WEB"],
+  "desktop": ["APP", "WEB"],
 }
 "edges": [
-  { "from": "APP", "to": "EXE", "carries": "claude-tooling" },
-  { "from": "APP", "to": "EXE", "carries": "app-source" },
-  { "from": "EXE", "to": "WEB", "carries": "release-mirror" },
 ]
```

- APP ยังเป็น root (`node tools/chain-lib.mjs | grep '^upstream'` ต้องพิมพ์ `upstream —`) — การรับสัญญา Eco เป็น **pull-pin** (ECO-G2) ไม่ใช่ edge เข้า APP
- `MIRROR_SETS` ใน `tools/mirror-claude.mjs` ต้องถอด EXE ออกพร้อมกัน ไม่งั้น `chain-check.yml` แดง
- ต้องแก้ข้อความใน `CLAUDE.md` (ตาราง repo), `chain/README.md` §1/§3, `QuetzaLib-DEV` (workspace + `scripts/setup.*` ที่ clone EXE)
- ทางเลือก ข (เก็บ EXE เป็น repo แพ็กเกจ Inno/MSIX): build artifact ข้าม repo + tag สองขบวน → เวอร์ชันหลุดกันง่าย — ไม่แนะนำ

---

## 7. Release / tag สำหรับ Windows build (แคตตาล็อกต้องใช้)

**ขบวนเดียว tag เดียว:** push `vX.Y.Z` → `release.yml` มี 2 job ขนานกัน → อัปโหลดเข้า **release เดียวกัน**

| job | runner | ผลลัพธ์ (ชื่อ asset) |
|---|---|---|
| android (มีแล้ว) | ubuntu | `quetzalib-vX.Y.Z.apk` |
| windows (ใหม่) | `windows-latest` | `quetzalib-vX.Y.Z-windows-x64.zip` (portable — **ต้องมี** สำหรับ ECO-K7) · `quetzalib-vX.Y.Z-windows-x64-setup.exe` (Inno Setup) · `SHA256SUMS.txt` |

เหตุผลที่ไม่แยก tag `win-v*`: `update_service.dart` ฝั่ง Android เรียก `releases/latest` — release ที่มีแต่ไฟล์ Windows จะกลายเป็น "latest"
แล้ว Android หา `.apk` ไม่เจอ (บทเรียน "สอง release train ใน repo เดียว" — DraconDex `UPDATE.md` §2.8 ที่ ECO-K4 อ้าง)

portable zip มี `quetzalib.exe` + `quetzalib-mcp.exe` + `data/` ของ Flutter + `sqlite3.dll` · setup.exe ติดตั้งแบบต่อผู้ใช้ (`%LOCALAPPDATA%\Programs\QuetzaLib`, ไม่ต้อง admin)
และ**ไม่**ลงทะเบียน `.zeco` เป็น Default (ECO-C9: Default เป็นของ Hub — แอปเพิ่มแค่ `OpenWithProgids`)

แถวใน `eco.json` (ECO-K3) ที่เสนอ:

```json
{
  "id": "quetzalib", "code": "qzl", "name": "QuetzaLib",
  "builds": [{
    "build": "exe", "platform": "windows-x64",
    "releaseRepo": "ZYDRAXYL/QuetzaLib-APP", "tagPattern": "v*", "rank": "version",
    "assets": { "installer": "quetzalib-v*-windows-x64-setup.exe", "portable": "quetzalib-v*-windows-x64.zip" },
    "minHub": "1.0.0"
  }],
  "formats": {
    "writes": [{"format": "qzl.library", "versions": ">=1.0.0 <2.0.0"}, {"format": "eco.entity-set", "versions": ">=1.0.0 <2.0.0"}],
    "reads":  [{"format": "qzl.library", "majors": [1]}, {"format": "eco.entity-set", "majors": [1]}]
  },
  "mcp": {"command": "quetzalib-mcp.exe", "args": [], "protocols": ["2025-11-25"]},
  "ecoProtocol": 1
}
```

- `releaseRepo` = QuetzaLib-APP (public, เป็นที่ที่ `release.yml` ปล่อยอยู่แล้ว) — ย้ายไป QuetzaLib-WEB เมื่อ handler `release-mirror` ทำงานจริง
  (`chain/README.md` §4) — ECO-K4 ต้องการแค่ repo public + กรองด้วย `tagPattern` + เลือกเวอร์ชันสูงสุด
- `"build": "exe"` ใน `eco.json` หมายถึง "build สำหรับ Windows" ของ Hub ไม่เกี่ยวกับ repo QuetzaLib-EXE
- ❓ installer แบบไหน + ซื้อ code-signing cert หรือไม่ → Grill Q11, Q14

## 8. เวอร์ชัน

| เวอร์ชัน (ECO-G3) | ของ QuetzaLib | กฎ |
|---|---|---|
| app version | `pubspec.yaml` `version: X.Y.Z+B` | skill `version-update` เดิม: semver + `B` นับขึ้นทีละ 1 ทุก release ห้ามถอย — **Android กับ Windows ใช้ค่าเดียวกัน** (Flutter ใส่ `X.Y.Z` + `B` ลง FileVersion ของ .exe ให้เอง) |
| tag | `vX.Y.Z` (ไม่มี `+B`) | skill `build-release-git` เดิม |
| DB schema | `_dbVersion` ใน `database_service.dart` (8 → **9**) | migrate ทีละขั้นใน `onUpgrade` เหมือนเดิม · ต้องปฏิเสธ DB ที่ใหม่กว่า (04 §3) |
| `qzl.library` | `formatVersion "1.0"` | ECO-R2–R7 |
| backup `.zip` | `data.json formatVersion 1` | ตรึงไว้ — อ่านอย่างเดียว (04 §5) |
| `ecoProtocol` / MCP | `1` / `2025-11-25` | ECO-C3, ECO-C4 |

การเพิ่ม Windows build ทั้งก้อน = bump **minor** (`1.13.0` → `1.14.0`, ฟีเจอร์ใหม่) ตามตารางของ `version-update` ·
การเปลี่ยน schema v9 มี migration จึงไม่ใช่ major
