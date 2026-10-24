# 06 — การเชื่อมกับ Zydraxyl Eco

ทุกข้ออ้างสัญญา `Zydraxyl-HUB/Design/eco/ECO-CONTRACT.md` ด้วยรหัสกฎ — ไม่ทวนเนื้อหากฎ
QuetzaLib: `id` = `quetzalib` · `code` = `qzl` (ECO-I1) · format ของตัวเอง = `qzl.library` (ECO-I3)

## 1. ส่งออก / นำเข้า `.zeco`

### 1.1 ส่งออก
| ส่วนใน bundle (ECO-B2) | ของ QuetzaLib | กฎ |
|---|---|---|
| `manifest.json` | `format: "qzl.library"`, `formatVersion: "1.0"`, `producer: {app:"quetzalib", version, build:"exe"|"apk", platform}`, `source: {app, project: libraryUid, projectName, ref}` | ECO-B3 |
| part `primary` | `parts/library/library.json` — 04 §4 | ECO-R1–R8 |
| part `data` | `parts/entities/entities.json` — `eco.entity-set` kind `book` | ECO-E1 · **ต้อง** (Z.I.Z อ่าน — ECO-R9) |
| `renditions/index.html` | ตารางหนังสือ (ชื่อ · ผู้แต่ง · ซีรีส์ · สถานะ · ★) HTML ไฟล์เดียว ไม่มี script · CSS inline จาก token ธีม `daylight` + `prefers-color-scheme: dark` → `moonlight` | ECO-R9, ECO-T5 |
| `renditions/README.md` | รายการเดียวกันเป็น Markdown | ECO-R9 ควร |
| `renditions/preview.png` | **ไม่ทำใน v1** (format ข้อมูล = "ควร") | ECO-R9 |
| `assets/` | รูปปก/หน้าที่อยู่ในเครื่อง · `quality: full` · URL ภาพจาก Google Books ไม่ฝัง (เก็บเป็น `thumbnailUrl`) | ECO-R13 |

- `mimetype` เป็น entry แรกแบบ STORED (ECO-B2) — ตรวจว่า package `archive` เขียน entry ไม่บีบอัดได้ (`ArchiveFile` + `compress: false`) ⚠ ต้องทดสอบ
- ไม่มี ZIP64 · ≤ 2 GiB (ECO-R12) — คลังที่มีรูปหน้าเยอะมากอาจชนเพดาน → ส่งออกได้แบบ "ไม่รวมรูปหน้า" (`quality: none`)
- ตำแหน่งปลายทาง: ผู้ใช้เลือกเอง (UI) · ผ่าน MCP `eco_export` เท่านั้นที่ลงโฟลเดอร์ตายตัว (§2)

### 1.2 นำเข้า
| part หลักที่เจอ | QuetzaLib ทำ |
|---|---|
| `qzl.library` major 1 | นำเข้าแบบรวม (04 §5) ตามตาราง ECO-R15 แถว 6–7 |
| `qzl.library` major ใหม่กว่า / `minReader` สูงกว่า | ECO-R15 แถว 4–5: ปฏิเสธ + แสดง rendition + ปุ่มอัปเดต (ผ่าน Hub) |
| format อื่นที่มี part `eco.entity-set` | ECO-R15 แถว 3: เสนอ "เปิดด้วยแอปเจ้าของ" / ดูอย่างเดียว / **นำเข้าเฉพาะ entity `kind:"book"`** → คิวต้องตรวจ (v1, F47) — kind อื่นข้าม (ECO-R6) |
| format อื่นไม่มี entity-set | แสดง rendition ใน sandbox (ECO-R21) + "เปิดด้วย…" |

ทุกกรณี: พรีวิวก่อน + ขั้นนำเข้าอ่านไฟล์ใหม่ (ECO-R16) · atomic (ECO-R17) · ไม่เขียนกลับลงไฟล์ (ECO-R18) · `eid` ชน → ถาม (ECO-R19)
การแสดง `index.html` ใน Flutter: ไม่มี WebView ในแอป (และ WebView2 ไม่มีทุกเครื่อง — T1-C §3.3) → **แตกไฟล์ลง temp แล้วเปิดด้วยเบราว์เซอร์ของระบบ**
`ponytail: ECO-R21 ขอ CSP script-src 'none' — เบราว์เซอร์ระบบไม่บังคับให้ จึงเขียน <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self'; style-src 'unsafe-inline'"> แทรกก่อนเปิด · ถ้าไม่พอ ต้องมี viewer ในแอป` — ดูข้อเสนอ P5

## 2. MCP สำหรับ Z.I.Z

- server name ในคอนฟิกของ agent: `zydraxyl-quetzalib` · คำสั่ง `quetzalib-mcp.exe` (ECO-C4) · transport stdio → pipe (ECO-C5)
- ทุก tool ต้องมีสิทธิ์ตาม ECO-S1 ที่ผู้ใช้ให้**ในหน้าต่าง QuetzaLib** · ค่าเริ่มต้นไม่มีสิทธิ์
- คลังมีโปรเจกต์เดียว (`libraryUid`) — `project` ใน argument ทุกตัวต้องตรงค่านี้ ไม่งั้น error ที่อ่านรู้เรื่อง

### 2.1 ชุดมาตรฐาน (ECO-C6)

| tool | พฤติกรรมของ QuetzaLib |
|---|---|
| `eco_info` | app/version · `reads/writes` ตาม `eco.json` · สิทธิ์ปัจจุบัน · จำนวนเล่ม |
| `eco_list_projects` | 1 แถว: คลัง (ข้อมูลเดียวกับ locator) |
| `eco_search` | `{q, limit≤200, cursor?}` → ใช้ `library_search.dart` เดิม (ขยายชุดชื่อ — ยกเว้นชื่อเรื่อง) → `[{ref, name, kind:"book"}]` |
| `eco_get` | `ref[]` (≤ 200) → `eco.entity-set` · `native:true` → ชิ้น `qzl.library` ของเล่มนั้น (ไม่มีรูป) |
| `eco_export` | `{refs?}` → `.zeco` ลง `%LOCALAPPDATA%\QuetzaLib\exports\` (คลังไม่อยู่ในโปรเจกต์ Eco — ดู §4 และ P2) · ไม่รับ path จาก agent |
| `eco_propose` | `eco.entity-set` patch ≤ 500 entity (ECO-S10) → แปลงเป็น `BulkPatch` / เล่มใหม่ → `proposalId` + diff สรุป · **ไม่เขียน** |
| `eco_apply` | `proposalId` → S4 โหมดรีวิว (05 §5) → ผู้ใช้กด → เขียนผ่าน `LibraryProvider` · มี batch grant → เขียนเลย · snapshot ก่อนครั้งแรกของ session (ECO-S3) |
| `eco_delete` | `ref[]` → ยืนยันในแอปทุกครั้ง ไม่มี batch (ECO-S2) · ลงถังลบเหมือน `Del` |
| `eco_import` | path `.zeco` → เปิด S6 พรีวิวในหน้าต่าง · agent ได้แค่ผล "ผู้ใช้นำเข้า/ยกเลิก" |

### 2.2 tool เฉพาะ QuetzaLib (ECO-C8) — เขียนทุกตัว = สร้าง proposal เท่านั้น

| tool | args | สิทธิ์ | ทำอะไร |
|---|---|---|---|
| `qzl_query` | `{filters: {status?, categories?, series?, author?, language?, genre?, missing?: ["authors","series",…]}, sort?, limit≤500, cursor?}` | read | ค้นแบบมีโครงสร้าง — `missing` คือ "หาเล่มที่ข้อมูลขาด" ที่ Z.I.Z ต้องใช้บ่อยที่สุด |
| `qzl_stats` | `{from?, to?, groupBy: status|category|author|series|language|month}` | read | สรุปจำนวน + การอ่านจาก `reading_stamps` (F50) |
| `qzl_find_duplicates` | `{by: isbn|title_author}` | read | กลุ่มที่อาจซ้ำ → ref |
| `qzl_name_sets` | — | read | ชุดชื่อทั้งหมด |
| `qzl_propose_bulk` | `{refs[], ops: [{op: set|clear|replace|addCategory|removeCategory|addStamp, field?, value?, from?, to?, stampType?, at?}]}` | propose | = `BulkPatch` (04 §6) → `proposalId` + diff · ชื่อเรื่องต้องมี `confirmTitle` และผู้ใช้ยืนยันซ้ำ |
| `qzl_propose_add_books` | `{isbns[] ≤ 500, lookup: bool, categories?}` | propose | ตรวจ checksum + (ถ้า `lookup`) ค้น metadata ด้วย `book_lookup_service` → เล่มใหม่เข้า proposal (ซ้ำ = ระบุในผล) |
| `qzl_propose_name_set` | `{terms[], mergeWith?: ref}` | propose | เสนอชุดชื่อ (แทนการแก้ข้อมูลรายเล่ม) |

`eco_apply` ใช้กับ `proposalId` จากทุก tool ข้างบน — ผู้ใช้เห็นหน้ารีวิวเดียวกันเสมอ

### 2.3 Resources (ECO-C7)
`zydraxyl://quetzalib/<libraryUid>` (คลัง → สรุปสั้น) · `zydraxyl://quetzalib/<libraryUid>/<eid>` (เล่ม → entity-set 1 ตัว) — read เท่านั้น

### 2.4 สิ่งที่ไม่ออกทาง MCP เด็ดขาด (ECO-S6, allowlist)
Cloud Vision API key · ค่าใน `shared_preferences` · path ในเครื่อง · รูป (v1) · `replaceAllData` (กู้คืนทับทั้งคลัง — UI เท่านั้น) · ตาราง `eco_grants`/`eco_audit`
`notes` และ `stamps[].note` (บันทึกส่วนตัว) ออกเฉพาะเมื่อผู้ใช้เปิดตัวเลือก "ให้ AI อ่านบันทึก" ❓ Q9

## 3. Locator · instance · การเปิดจาก Hub

**ECO-L1/L2** — `%LOCALAPPDATA%\Zydraxyl\locator\quetzalib.json` เขียนแบบ atomic ทุกครั้งที่เปิดแอป/เปลี่ยนชื่อคลัง:
```json
{
  "format": "eco.locator", "formatVersion": "1.0", "app": "quetzalib", "appVersion": "1.14.0",
  "updatedAt": "2026-10-18T09:00:00Z",
  "projects": [{
    "projectUid": "0192f3a0-aaaa-7bbb-8ccc-000000000001", "name": "คลังของฉัน",
    "path": "C:\\Users\\me\\AppData\\Local\\QuetzaLib\\library",
    "openWith": "C:\\Users\\me\\AppData\\Local\\QuetzaLib\\library\\quetzalib.db",
    "kind": "library", "ecoProject": null, "lastOpenedAt": "2026-10-18T08:55:00Z",
    "nativeFormat": {"id": "qzl.db", "version": "9.0"}, "pinned": false
  }]
}
```
- `nativeFormat` = `user_version` ของ DB — ให้ Hub เทียบก่อนเปิดด้วยเวอร์ชันเก่า (ECO-K7) · `qzl.db` ไม่ใช่ format แลกเปลี่ยน (P3)
- **ECO-L5** `instances\quetzalib.json` + `instances\quetzalib.token` (ACL ผู้ใช้) ตอนรัน · ลบตอนปิด
- **ECO-C3** argv: `--eco-open zydraxyl://quetzalib/<libraryUid>[/<eid>]` → เปิดคลัง + เลือกเล่มนั้นในแผงรายละเอียด · `--eco-protocol 1` · exit `10`/`11`/`12`/`1` ตามสัญญา (`11` = uid ไม่ตรงคลัง)
- **ECO-C11** single instance: mutex ใน C++ runner · ตัวที่สองส่ง argv ด้วย `WM_COPYDATA` แล้วออก · ตัวแรกโฟกัสหน้าต่าง
- **ECO-C9** setup.exe เพิ่ม QuetzaLib ใน `OpenWithProgids` ของ `.zeco` เท่านั้น · ไม่มี Hub → เป็น Default ถ้ายังไม่มีใคร
- **ECO-C10** "คัดลอกลิงก์" ในเมนูเล่ม → `text/plain` + `text/html` ที่มี Eco reference
- deep link ขาออก (เปิด Z.I.Z) ใช้ `zydraxyl://` ผ่าน Hub (ECO-C2) — ไม่มี Hub → ปุ่มบอก "ต้องติดตั้ง Hub/Z.I.Z"

## 4. โปรเจกต์ Eco (ECO-L6/L7)

ข้อเสนอ: **คลังหนังสือเป็นของส่วนตัวข้ามโปรเจกต์ ไม่เป็นสมาชิกของโปรเจกต์ Eco** (เช่นโปรเจกต์นิยาย "Moonfall")
— แอปอื่นอ้างหนังสือด้วย Eco reference (`zydraxyl://quetzalib/<libraryUid>/<eid>`) ใน `links` ของ `project.json` ได้โดยไม่ต้องย้ายคลัง
`members.quetzalib` จึงไม่ถูกเขียนใน v1 · หลายคลัง (คลังต่อโปรเจกต์) = later (F52) ❓ Q5

## 5. รับสัญญาแบบ pull-pin (ECO-G2, ECO-R32)

QuetzaLib-APP เป็น root ของ chain ตัวเอง → **ไม่มี edge จากสัญญาเข้ามา** · เจ้าของเลื่อน pin เอง:
```bash
node tools/eco-contract.mjs --vendor --ref eco-vX.Y.Z   # เขียน eco/** + lib/eco/tokens.g.dart + eco/eco.lock.json
node tools/eco-contract.mjs --check                     # CI (เพิ่มใน .github/workflows/build.yml)
node tools/eco-contract.mjs --upstream                  # สัญญาขยับแล้วหรือยัง (chained-supporter ควรเรียก)
```
ไฟล์ vendored มีหัว "vendored from Zydraxyl-ECO — do not edit" · `tools/eco-contract.mjs` ไม่อยู่ใน `MIRROR_SETS` (repo ปลายทางของ QuetzaLib ไม่ต้องใช้)

## 6. Conformance (ECO-R28–R31)

| งาน | ที่ไหน |
|---|---|
| ผู้เขียน: `tool/make_fixtures.dart` สร้าง `qzl.library/1.0/*.zeco` จากคลังตัวอย่างคงที่ → diff กับที่ commit + validate JSON Schema | CI ของ QuetzaLib-APP → ส่ง PR เข้า `fixtures/qzl.library/1.0/` ของ repo สัญญา |
| fixture ที่ต้องมี: `minimal` (1 เล่มเฉพาะฟิลด์บังคับ) · `full` (ทุกฟิลด์ + รูป 2 ไฟล์ + stamp ทุกชนิด) · `thai` (ชื่อ/ชุดชื่อภาษาไทย NFC) · `unknown-fields` (ฟิลด์/stamp type ที่ไม่รู้จัก) | — |
| ผู้อ่าน: นำเข้า fixture ทุกตัวใน `reads` ลงคลังเปล่า (ECO-R30) | `test/eco/conformance_test.dart` |
| ผู้อ่านอื่นของ `qzl.library` | ไม่มีใน v1 (Z.I.Z อ่าน `eco.entity-set`) → compat matrix มีแค่ QuetzaLib ↔ ตัวเอง + entity-set |

## 7. Checklist Eco v1 ของ QuetzaLib (ECO-CONTRACT §17)

| ข้อ | สถานะออกแบบ | อยู่ที่ |
|---|---|---|
| vendor + lock + `--check` | ✅ ออกแบบแล้ว | §5 |
| ส่งออก `.zeco` + rendition | ✅ | §1.1 |
| นำเข้าตาม ECO-R15 + พรีวิว | ✅ | §1.2, 05 §7 |
| ผ่าน fixture | ✅ | §6 |
| locator + instance | ✅ | §3 |
| MCP stdio + ชุดมาตรฐาน | ✅ | §2 |
| สิทธิ์ · snapshot · audit | ✅ | 04 §2, §7 |
| `--eco-open` + single instance | ✅ | §3 |
| อ่านลายเซ็น `eco.json` | ⬜ ไม่ทำใน v1 (ใช้แค่ "เปิดด้วย…" ผ่าน Hub) | — |
| token ร่วม | ✅ | 05 §6 |
| ปฏิเสธเขียนโปรเจกต์ที่ใหม่กว่า | ✅ | 04 §3 |

## 8. ข้อเสนอเพิ่มเข้า Eco contract

| # | ข้อเสนอ | เหตุผล |
|---|---|---|
| P1 | ECO-T3: generator ออก **`eco_theme.g.dart`** (`ddxThemeData()` + เทสต์ contrast ของ Material role ทุกตัว × 32 ธีม) คู่กับ `tokens.g.dart` | QuetzaLib, Ourobask, DraconDex APK เขียน mapping เดียวกันสามที่จะ drift (T4-C §6) |
| P2 | ECO-C6 `eco_export`: แอปที่ไม่มีโปรเจกต์ Eco (`ecoProject: null`) ให้ส่งออกลง `<appData>\exports\` ของแอป และคืน path ในผล | ข้อความปัจจุบันบังคับ `<project>/.zydraxyl/exports/` ซึ่งคลังส่วนตัวไม่มี |
| P3 | ECO-L1: ระบุว่า `nativeFormat.id` เป็นค่าบอกข้อมูล (ไม่ต้องลงทะเบียนใน ECO-I3) + เพิ่ม `kind: "library"` ในตัวอย่าง | กัน registry รก |
| P4 | ใส่โค้ด C++ ร่วมสำหรับแอป Flutter (`native/windows/eco_bridge.{h,cpp}`: single instance + pipe server ที่ตั้ง DACL/flag ตาม ECO-C5 + drop) ใน repo สัญญา แล้ว vendor byte-identical | QuetzaLib กับ Ourobask ต้องเขียนโค้ด security-sensitive ชุดเดียวกัน |
| P5 | ECO-R21: กำหนดทางที่ยอมรับสำหรับแอปที่ไม่มี WebView — เปิดในเบราว์เซอร์ระบบหลังแทรก `<meta CSP>` หรือแสดง `README.md` แทน | Flutter desktop ไม่มี WebView ในตัว |
| P6 | ECO-E1: ลงทะเบียนค่า `kind` ร่วม `book` (และ field ที่แนะนำ: `isbn13`, `authors[]`, `series`, `seriesVolume`, `status`) | ให้ Z.I.Z แปลง Excel → หนังสือ แล้ว QuetzaLib/DraconDex เข้าใจตรงกัน |
| P7 | `eco.app.*` dot color ของ QuetzaLib = เขียวหยก-ฟ้า (hue ~170°) ไม่ใช่มรกต | T4-C §1.1 ห้าม dot อยู่ในย่านเขียวที่หมายถึง success — accent ยังเป็นมรกตได้ (ECO-T2) ❓ Q12 |

**accent + glyph ที่เสนอ (ECO-T2):** accent มรกต `#1B7A3C` (ธีมสว่าง) · glyph = ขนนกเควทซัลบนสันหนังสือ (จากไอคอนแอปเดิม `assets/icon/QuetzaLib_Icon.png`)
