# Ensure script runs with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit
}

# Step 1: Install Chocolatey
Write-Host "Installing Chocolatey..." -ForegroundColor Green
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Refresh environment to use choco immediately
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Step 2: Install Windows Updates (if possible on tiny11)
Write-Host "Checking for Windows Updates..." -ForegroundColor Green
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}
Import-Module PSWindowsUpdate
Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false

# Step 3: Customize Taskbar (Remove Search, Task View, Widgets; Keep Start Only)
Write-Host "Customizing Taskbar..." -ForegroundColor Green
# Remove Search
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -ErrorAction SilentlyContinue
# Remove Task View
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -ErrorAction SilentlyContinue
# Remove Widgets
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -ErrorAction SilentlyContinue

# Move Taskbar to Left (tiny11 might not support natively, fallback to ExplorerPatcher if needed)
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name "Settings" -Value ([byte[]](0x30,0x00,0x00,0x00,0xFE,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -ErrorAction Stop
} catch {
    Write-Host "Taskbar move failed. Installing ExplorerPatcher as fallback..." -ForegroundColor Yellow
    choco install explorerpatcher -y
}

# Step 4: Enable Dark Mode
Write-Host "Enabling Dark Mode..." -ForegroundColor Green
# System-wide dark mode
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
# Apps dark mode
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0

# Step 5: Install Chocolatey Packages
Write-Host "Installing Chocolatey packages..." -ForegroundColor Green
$packages = @(
    "steam",
    "discord",
    "nvidia-display-driver",
    "librewolf",
    "git",
    "vscodium"
)
foreach ($pkg in $packages) {
    Write-Host "Installing $pkg..." -ForegroundColor Cyan
    choco install $pkg -y
}

# Step 6: Extra Recommendations (Gaming/Developer Essentials)
Write-Host "Installing recommended extras..." -ForegroundColor Green
$extras = @(
    "7zip",          # File compression
    "notepadplusplus", # Lightweight text editor
    "everything",    # Fast file search
    "pwsh"           # PowerShell Core for better scripting
)
foreach ($extra in $extras) {
    Write-Host "Installing $extra..." -ForegroundColor Cyan
    choco install $extra -y
}

# Step 7: Finalize
Write-Host "Setup complete! Rebooting is recommended to apply all changes." -ForegroundColor Green
pause
