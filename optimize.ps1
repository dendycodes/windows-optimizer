# Windows 10 Post-Install Optimizer
# Triggered via Flipper Zero BadUSB. Must run elevated (the launcher handles this).
# Auto items apply immediately with a progress bar. Optional items ask Y/N one at a time - answer with your real keyboard.

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "This script must be run as Administrator. Aborting." -ForegroundColor Red
    exit
}

$Host.UI.RawUI.WindowTitle = "Windows Post-Install Optimizer"
$ErrorActionPreference = 'Stop'
$summary = [System.Collections.Generic.List[psobject]]::new()

function Write-Banner {
    Write-Host ""
    Write-Host "  #############################################" -ForegroundColor Magenta
    Write-Host "  ##     Windows Post-Install Optimizer      ##" -ForegroundColor Magenta
    Write-Host "  #############################################" -ForegroundColor Magenta
    Write-Host ""
}

function Confirm-Step($Message) {
    $resp = Read-Host "$Message (Y/N)"
    return $resp -match '^[Yy]'
}

function Add-Summary($Icon, $Label, $Status) {
    $summary.Add([pscustomobject]@{ Icon = $Icon; Label = $Label; Status = $Status })
}

function Get-RegValue($Path, $Name) {
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

function Test-SvcDisabled($Name) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return [bool]($svc -and $svc.StartType -eq 'Disabled')
}

function Get-SystemDriveMediaType {
    try {
        $partition = Get-Partition -DriveLetter C -ErrorAction Stop
        $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
        $physicalDisk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq $disk.Number }
        if ($physicalDisk -and $physicalDisk.MediaType -in @('SSD', 'HDD')) {
            return $physicalDisk.MediaType
        }
    } catch {}
    return 'Unknown'
}

function Disable-SvcSafe($Name, $Label) {
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType Disabled
    } else {
        Write-Host "      (!) $Label service not found on this system, skipping." -ForegroundColor DarkYellow
    }
}

function Invoke-Spinner {
    param([string]$Message, [scriptblock]$Action)
    $job = Start-Job -ScriptBlock $Action
    $frames = @('|', '/', '-', '\')
    $i = 0
    while ($job.State -eq 'Running') {
        Write-Host -NoNewline ("`r      {0} {1}" -f $frames[$i % $frames.Length], $Message)
        Start-Sleep -Milliseconds 120
        $i++
    }
    Write-Host ("`r" + (' ' * ($Message.Length + 10)) + "`r") -NoNewline
    Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $job
}

function Invoke-AutoStep {
    param([int]$Index, [int]$Total, [string]$Icon, [string]$Label, [scriptblock]$Action, [scriptblock]$Test = $null)
    Write-Progress -Activity "Applying automatic optimizations" -Status "$Icon $Label" -PercentComplete (($Index / $Total) * 100)
    $already = $false
    if ($Test) { try { $already = & $Test } catch { $already = $false } }
    if ($already) {
        Write-Host ("  {0} {1,-42} [Already Set]" -f $Icon, $Label) -ForegroundColor Cyan
        Add-Summary $Icon $Label 'AlreadySet'
        return
    }
    try {
        & $Action
        Start-Sleep -Milliseconds 150
        Write-Host ("  {0} {1,-42} [OK]" -f $Icon, $Label) -ForegroundColor Green
        Add-Summary $Icon $Label 'Applied'
    } catch {
        Write-Host ("  {0} {1,-42} [FAILED]" -f $Icon, $Label) -ForegroundColor Red
        Write-Host ("      Error: {0}" -f $_.Exception.Message) -ForegroundColor DarkRed
        Add-Summary $Icon $Label 'Failed'
    }
}

function Invoke-OptionalStep {
    param([int]$Index, [int]$Total, [string]$Icon, [string]$Question, [scriptblock]$Action, [scriptblock]$Test = $null)
    Write-Progress -Activity "Optional items" -Status "Item $Index of $Total" -PercentComplete (($Index / $Total) * 100)
    $prompt = "  {0} [{1}/{2}] {3}" -f $Icon, $Index, $Total, $Question
    $already = $false
    if ($Test) { try { $already = & $Test } catch { $already = $false } }
    if ($already) {
        Write-Host $prompt -ForegroundColor DarkCyan
        Write-Host "      -> Already set, nothing to do" -ForegroundColor Cyan
        Add-Summary $Icon $Question 'AlreadySet'
        return
    }
    if (Confirm-Step $prompt) {
        try {
            & $Action
            Write-Host "      -> Applied" -ForegroundColor Green
            Add-Summary $Icon $Question 'Applied'
        } catch {
            Write-Host ("      -> Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
            Add-Summary $Icon $Question 'Failed'
        }
    } else {
        Write-Host "      -> Skipped" -ForegroundColor DarkGray
        Add-Summary $Icon $Question 'Skipped'
    }
}

Write-Banner

$driveType = Get-SystemDriveMediaType
switch ($driveType) {
    'SSD' {
        Write-Host "  💾 Detected system drive: SSD" -ForegroundColor Cyan
        $searchAdvice = "not recommended on your SSD, leave enabled"
        $sysMainAdvice = "recommended on your SSD"
    }
    'HDD' {
        Write-Host "  💾 Detected system drive: HDD" -ForegroundColor Cyan
        $searchAdvice = "recommended on your HDD"
        $sysMainAdvice = "not recommended on your HDD, leave enabled"
    }
    default {
        Write-Host "  💾 Could not auto-detect drive type - decide based on your own hardware" -ForegroundColor DarkYellow
        $searchAdvice = "recommended on HDDs only"
        $sysMainAdvice = "recommended on SSDs only"
    }
}

# --- Auto items ---
Write-Host "  Auto items (applying now, no prompts):" -ForegroundColor Magenta
$autoTotal = 5
$n = 0

Invoke-AutoStep -Index (++$n) -Total $autoTotal -Icon "🖼️ " -Label "Visual effects -> best performance" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting') -eq 2
} -Action {
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type Binary -Force
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Type DWord -Force
}

Invoke-AutoStep -Index (++$n) -Total $autoTotal -Icon "💽" -Label "Enabling Storage Sense" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01') -eq 1
} -Action {
    $ssPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    if (-not (Test-Path $ssPath)) { New-Item -Path $ssPath -Force | Out-Null }
    Set-ItemProperty -Path $ssPath -Name '01' -Value 1 -Type DWord -Force
}

Invoke-AutoStep -Index (++$n) -Total $autoTotal -Icon "📴" -Label "Disabling background apps" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled') -eq 1
} -Action {
    $bgPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    if (-not (Test-Path $bgPath)) { New-Item -Path $bgPath -Force | Out-Null }
    Set-ItemProperty -Path $bgPath -Name 'GlobalUserDisabled' -Value 1 -Type DWord -Force
}

Invoke-AutoStep -Index (++$n) -Total $autoTotal -Icon "🎮" -Label "Enabling Game Mode" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -eq 1
} -Action {
    $gmPath = 'HKCU:\Software\Microsoft\GameBar'
    if (-not (Test-Path $gmPath)) { New-Item -Path $gmPath -Force | Out-Null }
    Set-ItemProperty -Path $gmPath -Name 'AutoGameModeEnabled' -Value 1 -Type DWord -Force
}

Invoke-AutoStep -Index (++$n) -Total $autoTotal -Icon "🛠️ " -Label "Ensuring Automatic Maintenance is on" -Test {
    $v = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled'
    ($null -eq $v) -or ($v -eq 0)
} -Action {
    $maintPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'
    if (Test-Path $maintPath) { Set-ItemProperty -Path $maintPath -Name 'MaintenanceDisabled' -Value 0 -Type DWord -Force }
}

Write-Progress -Activity "Applying automatic optimizations" -Completed

# --- Optional items ---
Write-Host "`n  Optional items (answer Y/N for each):" -ForegroundColor Magenta
$optTotal = 13
$m = 0

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🔍" -Question "Disable Cortana" -Test {
    (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana') -eq 0
} -Action {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name 'AllowCortana' -Value 0 -Type DWord -Force
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🌐" -Question "Disable Internet Explorer 11 Windows feature" -Test {
    (Get-WindowsOptionalFeature -Online -FeatureName Internet-Explorer-Optional-amd64 -ErrorAction SilentlyContinue).State -eq 'Disabled'
} -Action {
    Invoke-Spinner -Message "Removing Internet Explorer 11, this can take a bit..." -Action {
        Disable-WindowsOptionalFeature -Online -FeatureName Internet-Explorer-Optional-amd64 -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🪟" -Question "Turn off transparency effects" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency') -eq 0
} -Action {
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type DWord -Force
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🎞️ " -Question "Disable window animations" -Test {
    (Get-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate') -eq '0'
} -Action {
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '0' -Type String -Force
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "📄" -Question "Set pagefile automatically based on detected RAM (1.5x/3x)" -Action {
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $initialMB = [math]::Round($ramGB * 1.5 * 1024)
    $maxMB = [math]::Round($ramGB * 3 * 1024)
    Write-Host ("      Detected RAM: {0} GB -> Initial {1} MB / Max {2} MB" -f $ramGB, $initialMB, $maxMB) -ForegroundColor Cyan
    $cs = Get-WmiObject Win32_ComputerSystem
    $cs.AutomaticManagedPagefile = $false
    $cs.Put() | Out-Null
    $pf = Get-WmiObject Win32_PageFileSetting -Filter "Name='C:\\pagefile.sys'"
    if (-not $pf) {
        Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{ Name = 'C:\pagefile.sys'; InitialSize = $initialMB; MaximumSize = $maxMB } | Out-Null
    } else {
        $pf.InitialSize = $initialMB
        $pf.MaximumSize = $maxMB
        $pf.Put() | Out-Null
    }
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "📊" -Question "Reduce Windows telemetry to Basic" -Test {
    (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry') -eq 1
} -Action {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name 'AllowTelemetry' -Value 1 -Type DWord -Force
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "📶" -Question "Turn off Delivery Optimization (P2P update downloads)" -Test {
    (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode') -eq 0
} -Action {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name 'DODownloadMode' -Value 0 -Type DWord -Force
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "☁️ " -Question "Switch DNS to Cloudflare (1.1.1.1 / 1.0.0.1) on active adapters" -Test {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if (-not $adapters) { return $false }
    foreach ($a in $adapters) {
        $servers = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        if ($servers -notcontains '1.1.1.1') { return $false }
    }
    return $true
} -Action {
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('1.1.1.1', '1.0.0.1')
    }
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🔎" -Question "Disable Windows Search service ($searchAdvice)" -Test {
    Test-SvcDisabled 'WSearch'
} -Action {
    Disable-SvcSafe -Name 'WSearch' -Label 'Windows Search'
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "📡" -Question "Disable Connected User Experiences and Telemetry (DiagTrack)" -Test {
    Test-SvcDisabled 'DiagTrack'
} -Action {
    Disable-SvcSafe -Name 'DiagTrack' -Label 'Connected User Experiences and Telemetry'
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "🖨️ " -Question "Disable Print Spooler service (only if you never print)" -Test {
    Test-SvcDisabled 'Spooler'
} -Action {
    Disable-SvcSafe -Name 'Spooler' -Label 'Print Spooler'
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "⚡" -Question "Disable SysMain / SuperFetch ($sysMainAdvice)" -Test {
    Test-SvcDisabled 'SysMain'
} -Action {
    Disable-SvcSafe -Name 'SysMain' -Label 'SysMain'
}

Invoke-OptionalStep -Index (++$m) -Total $optTotal -Icon "💡" -Question "Turn off tips, tricks and suggestions notifications" -Test {
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled') -eq 0 -and
    (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled') -eq 0
} -Action {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-ItemProperty -Path $path -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'SoftLandingEnabled' -Value 0 -Type DWord -Force
}

Write-Progress -Activity "Optional items" -Completed

# --- Summary ---
Write-Host ""
Write-Host "  =============== Summary ===============" -ForegroundColor Magenta
foreach ($item in $summary) {
    switch ($item.Status) {
        'Applied'    { Write-Host ("  ✅ {0}" -f $item.Label) -ForegroundColor Green }
        'AlreadySet' { Write-Host ("  ☑️  {0} (already set)" -f $item.Label) -ForegroundColor Cyan }
        'Failed'     { Write-Host ("  ❌ {0}" -f $item.Label) -ForegroundColor Red }
        default      { Write-Host ("  ⏭️  {0}" -f $item.Label) -ForegroundColor DarkGray }
    }
}
Write-Host "  =========================================" -ForegroundColor Magenta

Write-Host "`n  (!) Some changes (pagefile, IE11 removal, animations) need a restart to fully apply." -ForegroundColor Yellow
if (Confirm-Step "Restart now") {
    Write-Host "  🔁 Restarting..." -ForegroundColor Cyan
    Restart-Computer -Force
} else {
    Write-Host "  Remember to restart later." -ForegroundColor Yellow
}
