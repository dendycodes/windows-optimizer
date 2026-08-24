# Windows Post-Install Optimizer

A PowerShell script that automates the optional post-install tweaks from my Windows 10 setup checklist. Runs auto items immediately (visual effects, Storage Sense, background apps, Game Mode, Automatic Maintenance) and asks Y/N for the rest (Cortana, IE11, transparency, animations, pagefile, telemetry, Delivery Optimization, DNS, services, notifications). Each item checks whether it's already configured before doing anything, and detects SSD/HDD to tailor its recommendations.

Output is plain ASCII (aligned dot-leaders, boxed banner, `OK`/`SET`/`SKIP`/`FAIL` status tags) so it renders correctly in any console codepage/font — no emoji glyphs that show up as tofu boxes.

```
  ============================================================================
                         WINDOWS POST-INSTALL OPTIMIZER
  ============================================================================

  [1/5] Visual effects -> best performance ................................ OK
  [2/5] Enabling Storage Sense ........................................... SET

  [1/13] Disable Cortana
         Result: Applied
```

Meant to be launched via a Flipper Zero BadUSB payload that opens an elevated PowerShell and runs:

```powershell
iwr -useb https://raw.githubusercontent.com/dendycodes/windows-optimizer/main/optimize.ps1 | iex
```

Requires Administrator privileges (self-checks and aborts otherwise).
