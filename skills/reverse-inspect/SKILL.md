---
name: reverse-inspect
description: Evidence-based reverse engineering and binary or bundle inspection using REA (rea-agents MCP and CLI), Ghidra, goblin, and static analysis tools. Analyzes ELF, PE, Mach-O binaries, Electron asar packages, JS bundles, APKs, and HAR captures. Triggers include reverse engineer, binary incele, exe analiz, elf incele, asar ac, rea ile bak, decompile et, kapali kaynak incele.
user-invocable: true
metadata:
  type: workflow
  version: "1.3"
---

# Reverse Inspect (REA Workflow)

Evidence-based reverse engineering and structural analysis of compiled binaries, Electron/JS bundles, mobile packages, and network captures using **REA (`rea-agents`)** and standard Linux inspection tools.

## When

Inspecting, decompiling, tracing, or reversing a closed-source binary (`.elf`, `.exe`, `.so`, `.dll`, Mach-O), Electron `.asar`, AppImage, obfuscated JS bundle, `.apk`, `.wasm`, or `.har` capture.

## Workflow

1. **Identify Target Type & Format:**
   - **Native Binary (`ELF` / `PE` / `Mach-O`):** Headers, architecture, dynamic libraries, and symbols (`file`, `readelf -d`, `nm -D`, `strings`, or `rea` MCP tools).
   - **Electron / Desktop Bundle (`.asar` / AppImage / `.deb`):** Extract/list contents, inspect `package.json`, main/preload entry points, and IPC channels (`ipcMain` / `ipcRenderer`).
   - **Web / JS Bundle & Network (`.har` / Sourcemaps):** API endpoints, auth headers, and module dependency graphs.
   - **Mobile / Bytecode (`.apk` / `.wasm`):** Manifest, permissions, and decompiled classes via `rea` / `jadx`.
   - **Custom Asset Blobs & Resource Banks (`.dat` / `.bin` / proprietary containers):** Check for unencrypted or lightly packed embedded signatures (`RIFF`/`WAVE`, `PNG`, `OGG`, `PK`, `SQLite`) using `binwalk` or a short Python offset-carving script; inspect unused/placeholder assets and runtime temp-file side effects (e.g. files unpacked into `System32` / `%TEMP%`).
   - **Hidden Debug Modes & USB/HID Byte Protocols:** Search strings, resources, CLI flags, and config/registry keys in legacy PE/ELF binaries for leftover developer test menus/forms (`Form1`); for USB/HID peripherals, map init handshakes, control opcodes, and state readbacks via `lsusb -v`, `usbmon`/Wireshark, or `hidraw`.
2. **Execute REA (MCP or CLI):**
   - Prefer the active `rea` MCP server tools, or run CLI directly:
     ```bash
     npx -y rea-agents doctor
     npx -y rea-agents inspect "<target-path>"
     ```
3. **Preserve Evidence Provenance:**
   - Every architectural claim must cite a concrete symbol name, function address/offset, IPC channel string, or extracted file path.
   - Never hallucinate decompiled logic when symbols are stripped; mark unverified parts `Kanıt bulunamadı (stripped)`.

## Output

Concise structured report in the user's language (`# Tersine Mühendislik Raporu: [Hedef]`):
- **Dosya Tipi, Koruma & Analiz Motoru:** Format, stripped/obfuscated status, engine used.
- **1. Giriş Noktaları & Mimari Harita:** Entrypoint/Main, key symbols/modules, external libs/packages.
- **2. Kanıt Tabanlı Bulgular:** `[Bulgu]` -> `Kanıt (Sembol / Offset / String / Path)`.
- **3. Yeniden Uygulama Notları:** 2–3 step clean reimplementation outline (when relevant).

## Constraints

- Static analysis and controlled inspection only; never execute untrusted binaries directly on the host without explicit user instruction and sandboxing.
- Never invent symbol names, offsets, or API endpoints; missing data -> `Veri bulunamadı`.
