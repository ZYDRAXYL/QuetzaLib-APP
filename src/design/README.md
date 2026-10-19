# QuetzaLib PC + Eco — เอกสารออกแบบ

> **สถานะ: ออกแบบ ยังไม่สร้าง** · ร่าง 2026-10-18 · ยังไม่มีข้อไหนถูกรับ
> ทุกข้อที่มี **❓ รอเจ้าของตัดสิน → Grill Q<n>** ดูคำถามที่ [`07-grill-me.md`](./07-grill-me.md)

QuetzaLib คือคลังหนังสือ/นิยายส่วนตัว (สแกน ISBN → ค้นข้อมูล → เก็บใน SQLite บนเครื่อง + ไทม์ไลน์สถานะการอ่าน)
วันนี้มีแค่ Android + PWA เอกสารชุดนี้ออกแบบ **QuetzaLib เวอร์ชัน PC (Windows)** ที่เป็นสมาชิกของ Zydraxyl Eco:
เปิด/แก้ข้อมูลจำนวนมากได้สะดวกบนจอใหญ่ และให้ **Z.I.Z** ค้นหา/เสนอแก้ข้อมูลคลังผ่าน MCP ได้
Eco v1 รองรับ PC เท่านั้น (ข้อกำหนดของเจ้าของ) — Android ยังอยู่ แต่ไม่ใช่สมาชิก Eco v1

## สรุปคำตัดสินที่เสนอ (1 หน้า)

| เรื่อง | ข้อเสนอ | เอกสาร |
|---|---|---|
| เครื่องยนต์ PC | **Flutter Windows desktop จาก `lib/` เดิม** — ไม่ใช่ Electron ห่อ web build | [02](./02-architecture.md) §1 |
| QuetzaLib-EXE | ถอดออกจาก chain (`desktop` chain = `APP > WEB`) — ❓ Q10 | [02](./02-architecture.md) §6 |
| plugin ที่พังบน Windows | สแกนกล้อง → USB scanner (keyboard-wedge) + พิมพ์เอง · ML Kit OCR → Cloud Vision เท่านั้น · ตัวอัปเดต APK → Hub/WEB | [02](./02-architecture.md) §3 |
| ที่เก็บคลัง | `%LOCALAPPDATA%\QuetzaLib\library\` (DB + รูป) — ❓ Q4 | [04](./04-internals.md) §1 |
| มือถือ ↔ PC | `.zeco` (`qzl.library`) นำเข้าแบบ **รวม** ตาม `eid` · `.zip` เดิมอ่านได้ต่อ — ❓ Q3 | [04](./04-internals.md) §5 |
| หน้าจอ PC | 3 แผง (กลุ่ม · รายการ · รายละเอียด) + เลือกหลายเล่ม + แก้พร้อมกันพร้อมพรีวิว diff + เพิ่มด่วนด้วยสแกนเนอร์ | [05](./05-ux-ui.md) |
| Eco | ส่งออก/นำเข้า `.zeco` · locator · MCP stdio ผ่าน named pipe · สิทธิ์/snapshot/audit ตาม ECO-S1–S4 | [06](./06-eco-integration.md) |
| release | tag `v*` เดิมขบวนเดียว: APK + Windows zip (portable) + setup.exe ใน release เดียวกัน — ❓ Q11 | [02](./02-architecture.md) §7 |

## ลำดับการอ่าน

| # | ไฟล์ | อ่านเมื่อ |
|---|---|---|
| 1 | [`07-grill-me.md`](./07-grill-me.md) | **เจ้าของ: อ่านก่อน** — 14 คำถามที่ต้องตัดสิน |
| 2 | [`01-research-summary.md`](./01-research-summary.md) | อยากรู้ว่าข้อเสนอมาจากไหน |
| 3 | [`02-architecture.md`](./02-architecture.md) | stack, process, โฟลเดอร์, chain, release |
| 4 | [`03-features.md`](./03-features.md) | รายการฟีเจอร์ MVP / v1 / later |
| 5 | [`04-internals.md`](./04-internals.md) | schema v9, `qzl.library`, bulk edit, การ migrate |
| 6 | [`05-ux-ui.md`](./05-ux-ui.md) | หน้าจอ, flow, ธีม, a11y |
| 7 | [`06-eco-integration.md`](./06-eco-integration.md) | export/import, MCP สำหรับ Z.I.Z, locator, fixture |

## ข้อมูลอ้างอิง

- สัญญา Eco: `Zydraxyl-HUB/Design/eco/ECO-CONTRACT.md` (อ้างด้วยรหัสกฎ เช่น ECO-R9)
- งานค้นคว้า: `Zydraxyl-HUB/Design/eco/research/` — T1-C · T2-C · T3-C · T4-C (ส่วน `[QZL]`) + T5
- กฎของ repo นี้: [`../../CLAUDE.md`](../../CLAUDE.md) · chain: [`../../chain/README.md`](../../chain/README.md)

## ขอบเขตของโฟลเดอร์นี้

`src/design/` เป็นเอกสารเท่านั้น ไม่มีโค้ด ไม่ถูก build — การแก้ `lib/`, `chain/`, `tools/`, `.claude/` ตามที่เอกสารนี้เสนอ
ต้องทำหลังเจ้าของตอบ Grill-me และต้องผ่านกลไก chain ของ repo (ไม่แก้ `chain.json` ด้วยมือ)
