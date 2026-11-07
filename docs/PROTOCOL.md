# MSI monitor protocol notes

Notes for contributors who want to add models or features. Everything here was found by reading
public material and static analysis of MSI's Windows software; nothing was confirmed on hardware
unless it says so.

## Transport

- USB HID, vendor `0x1462`, product `0x3fa4` ("MSI Gaming Controller"). MSI's software also lists
  `0x3fa3`, and `0x0416:0x5020` / `0x1038:0x1126` for older lighting controllers.
- Short commands: output report ID `1`, 64 bytes, ASCII.
  - Read: `"58" + code + CR` → `"5b" + code + value + CR`
  - Write: `"5b" + code + 3-character value + CR` → `"5600+"` when accepted
- Codes are five characters. Digits above 9 use the next ASCII characters (`:` `;` `<` `=` `>` `?` `@` `A` …).
- Long commands use a 256-byte buffer; their replies start with `5b001q` (all functions) or `5b00<1`
  (behaviour). Not used by this app.

## Codes seen in MSI Gaming Intelligence

MSI's `MonitorControlLibrary.dll` (version 0.1.4.9) contains this table. The app does not use the
codes below yet, because their value ranges are unknown and no test monitor supports them.

| Feature | Read code |
|---|---|
| Optix Scope / size / ratio | `002A0` / `002A1` / `002A2` |
| AI Vision | `002B0` |
| DSC | `002D0` |
| AI Dual Mode | `002E0` |
| RGB brightness | `00740` |
| Power LED | `008B0` |
| Eco mode | `008?0` |
| Auto brightness / custom | `008<1` / `008<3` |
| HDMI 2.1 | `008@0` |
| USB-C PD charging | `008A0` |
| KVM per port | `008>1` … `008>4` |
| Local dimming custom | `00491` |
| Halo dimming | `004A0` |
| Brightness uniformity | `004?0` |
| Saturation RGB / CMY / all | `004;0` / `004;1` / `004;2` |
| Hue RGB / CMY / all | `004<0` / `004<1` / `004<2` |
| Gamma (OLED) | `004@0` |
| OLED care: pixel shift, panel protect, notices | `00;00`, `00;10`, `00;20`–`00;81`, `00;90` |
| Panel name / resolution type | `001?0` / `001;0` |
| Factory serial | `00131` |

On the MAG401QR (firmware 112), `002A0`–`002A2` do not answer.

## Mystic Light

The lighting effects are not sent as short commands. MSI's `MSIMysticDll.dll` writes a HID
**feature report** to the same device:

- Older protocol: report ID `0x72`, 168 bytes. Two zones of 11 bytes each from byte 1
  (`mode, R1, G1, B1, speed, brightness, R2, G2, B2, option, option`), then per-LED RGB from byte 23.
- Newer ARGB protocol: report ID `0x82`, 123 bytes, 10 strips with a 12-byte stride; byte 121 stores to flash.
- Modes: 0 off, 1 static, 2 breathing, 3 flashing, 4 double flashing, 5 lighting, 6 marquee, 7 meteor,
  8 water drop, 9 rainbow, 25 rainbow, 26 rainbow wave, 31 random, 32 audio, 33 rainbow line, 37 advanced.
  Speed 0–2.

Which models use which layout is unknown. On the MAG401QR (firmware 112) the 168-byte `0x72` report is confirmed: zone 1 at bytes 1–11 drives the
back light, and `00860` must be on. A zone colour of 0,0,0 looks like the light is off.

## Firmware

MSI's updater picks a back end per scaler chip (Realtek, MediaTek, Novatek NT68500) and uses separate
ISP tools that erase and program the scaler, with one file per input. This app will not implement
flashing: a wrong or interrupted write leaves the monitor unusable.
