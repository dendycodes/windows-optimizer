# Windows Post-Install Optimizer

A PowerShell script that automates the optional post-install tweaks from my Windows 10 setup checklist. Runs auto items immediately (visual effects, Storage Sense, background apps, Game Mode, Automatic Maintenance) and asks Y/N for the rest (Cortana, IE11, transparency, animations, pagefile, telemetry, Delivery Optimization, DNS, services, notifications). Each item checks whether it's already configured before doing anything, and detects SSD/HDD to tailor its recommendations.

Meant to be launched via a Flipper Zero BadUSB payload that opens an elevated PowerShell and runs:

```powershell
iwr -useb https://raw.githubusercontent.com/dendycodes/windows-optimizer/main/optimize.ps1 | iex
```

Requires Administrator privileges (self-checks and aborts otherwise).
