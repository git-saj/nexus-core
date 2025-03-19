# Define Chocolatey packages at the top
$chocoPackages = @(
    "steam",
    "discord",
    "nvidia-display-driver",
    "librewolf",
    "git",
    "vscodium",
    "7zip",
    "notepadplusplus",
    "everything",
    "pwsh"
)

# Ensure script runs with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Step 1: Install Chocolatey if not present
Write-Host "Checking Chocolatey installation..." -ForegroundColor Green
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "Chocolatey installed." -ForegroundColor Green
} else {
    Write-Host "Chocolatey already installed." -ForegroundColor Gray
}

# Step 2: Install PSWindowsUpdate if needed
Write-Host "Checking PSWindowsUpdate prerequisites..." -ForegroundColor Green
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
    Write-Host "PSWindowsUpdate installed." -ForegroundColor Green
} else {
    Write-Host "PSWindowsUpdate already installed." -ForegroundColor Gray
}
Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue

# Step 3: Install Windows Updates
Write-Host "Installing Windows Updates..." -ForegroundColor Green
Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -Confirm:$false -IgnoreReboot -ErrorAction SilentlyContinue

# Step 4: Check for Pending Reboot (Post-Updates)
Write-Host "Checking for reboot after updates..." -ForegroundColor Green
$rebootPending = $false
$rebootKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
)
foreach ($key in $rebootKeys) {
    if (Test-Path $key) {
        $rebootPending = $true
        break
    }
}
if ($rebootPending) {
    Write-Host "Reboot required after updates. Restarting in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
    exit
}

# Step 5: Install/Upgrade Chocolatey Packages
Write-Host "Managing Chocolatey packages..." -ForegroundColor Green
foreach ($pkg in $chocoPackages) {
    Write-Host "Processing $pkg..." -ForegroundColor Cyan
    $installed = choco list | Where-Object { $_ -match "^$pkg\s" }
    if ($installed) {
        $upgradeOutput = choco upgrade $pkg -y --ignore-detected-reboot --no-progress --limit-output 2>&1
        if ($upgradeOutput -match "$pkg\|[^|]+\|[^|]+\|false") {
            Write-Host "$pkg is already up to date." -ForegroundColor Gray
        } else {
            Write-Host "$pkg upgraded." -ForegroundColor Green
        }
    } else {
        choco install $pkg -y --ignore-detected-reboot --no-progress --limit-output | Out-Null
        Write-Host "$pkg installed." -ForegroundColor Green
    }
}

# Step 6: Apply System and UI Customizations
Write-Host "Applying system and UI customizations..." -ForegroundColor Green
try {
    # Taskbar customizations
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $advancedProps = Get-ItemProperty -Path $regPath -ErrorAction Stop

    # Remove Search
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -ErrorAction Stop
    Write-Host "Search removed from taskbar." -ForegroundColor Green

    # Remove Task View
    if ($advancedProps.ShowTaskViewButton -ne 0) {
        Set-ItemProperty -Path $regPath -Name "ShowTaskViewButton" -Type DWord -Value 0 -ErrorAction Stop
        Write-Host "Task View removed from taskbar." -ForegroundColor Green
    } else {
        Write-Host "Task View already removed." -ForegroundColor Gray
    }

    # Remove Widgets
    $webExperience = Get-AppxPackage *WebExperience* -ErrorAction Stop
    if ($webExperience) {
        Remove-AppxPackage -Package $webExperience.PackageFullName -ErrorAction Stop
        Write-Host "Widgets removed via WebExperience package." -ForegroundColor Green
        Write-Host "Note: Widgets may return with updates; consider blocking in Settings if needed." -ForegroundColor Yellow
    } else {
        Write-Host "Widgets already removed." -ForegroundColor Gray
    }

    # Move Taskbar to Left
    if (-not $advancedProps.TaskbarAl -or $advancedProps.TaskbarAl -ne 0) {
        Set-ItemProperty -Path $regPath -Name "TaskbarAl" -Type DWord -Value 0 -ErrorAction Stop
        Write-Host "Taskbar moved to left." -ForegroundColor Green
    } else {
        Write-Host "Taskbar already on left." -ForegroundColor Gray
    }

    # Unpin all apps
    $taskbandPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
    if (Test-Path $taskbandPath) {
        Remove-Item -Path $taskbandPath -Recurse -ErrorAction Stop
        Write-Host "All apps unpinned from taskbar (effective on next logon)." -ForegroundColor Green
    } else {
        Write-Host "No apps pinned to taskbar." -ForegroundColor Gray
    }

    # Disable all user startup apps
    Write-Host "Disabling all user startup apps..." -ForegroundColor Cyan
    # Disable Registry Run entries (HKCU and HKLM, excluding system entries)
    $runKeys = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
    foreach ($key in $runKeys) {
        $runItems = Get-Item -Path $key -ErrorAction SilentlyContinue
        if ($runItems) {
            $runItems.Property | ForEach-Object {
                if ($_ -notmatch "MicrosoftEdgeAutoLaunch|OneDriveSetup|WindowsDefender") { # Exclude system entries
                    try {
                        Remove-ItemProperty -Path $key -Name $_ -ErrorAction Stop
                        Write-Host "Removed startup for $_ from $key." -ForegroundColor Green
                    } catch {
                        # Check for Discord specifically
                        if ($_ -match "Discord") {
                            Set-ItemProperty -Path $key -Name $_ -Value "" -Type String -ErrorAction Stop
                            Write-Host "Forced disable of Discord startup from $key." -ForegroundColor Green
                        } else {
                            Set-ItemProperty -Path $key -Name $_ -Value "" -Type String -ErrorAction SilentlyContinue
                            Write-Host "Could not remove $_ from $key; disabled instead." -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    }
    # Disable Startup folder items
    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupFolder) {
        Get-ChildItem -Path $startupFolder -File | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                Write-Host "Removed startup item $($_.Name)." -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove startup item $($_.Name)." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No startup folder items found." -ForegroundColor Gray
    }
    # Disable all user-related Scheduled Tasks (including Discord-specific)
    $startupTasks = Get-ScheduledTask | Where-Object { $_.Principal.UserId -eq $env:USERNAME -and $_.TaskPath -notlike "\Microsoft\Windows\System*" } -ErrorAction SilentlyContinue
    if ($startupTasks) {
        foreach ($task in $startupTasks) {
            try {
                if ($task.TaskName -match "Discord") {
                    Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop
                    Write-Host "Disabled Discord Scheduled Task $($task.TaskName)." -ForegroundColor Green
                } else {
                    Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop
                    Write-Host "Disabled Scheduled Task $($task.TaskName)." -ForegroundColor Green
                }
            } catch {
                Write-Host "Failed to disable Scheduled Task $($task.TaskName)." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No user Scheduled Tasks found." -ForegroundColor Gray
    }

    # Set Wallpaper with retry
    $wallpaperUrl = "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fi.pinimg.com%2Foriginals%2F3a%2F16%2F39%2F3a16396040f98fe8441864bbd001762d.jpg&f=1&nofb=1&ipt=781d1751377f9f50f93d4a8365896318022a94f87d986784062c88b8f222b090&ipo=images"
    $tempPath = "$env:TEMP\wallpaper.jpg"
    $attempts = 0
    $maxAttempts = 3
    while ($attempts -lt $maxAttempts) {
        try {
            (New-Object System.Net.WebClient).DownloadFile($wallpaperUrl, $tempPath)
            break
        } catch {
            $attempts++
            if ($attempts -eq $maxAttempts) {
                throw "Failed to download wallpaper after $maxAttempts attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds 2
        }
    }
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $tempPath -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "6" -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -ErrorAction Stop
    RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True
    Write-Host "Wallpaper set." -ForegroundColor Green

    # Enable Dark Mode
    $themePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -ErrorAction Stop
    Write-Host "Dark mode enabled." -ForegroundColor Green

    # Disable Enhance Pointer Precision
    $mousePath = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value 0 -ErrorAction Stop
    Write-Host "Enhance Pointer Precision disabled." -ForegroundColor Green
} catch {
    Write-Host "Error during customization: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 7: Check for Pending Reboot and Finalize
Write-Host "Setup complete! Checking for reboot..." -ForegroundColor Green
$rebootPending = $false
foreach ($key in $rebootKeys) {
    if (Test-Path $key) {
        $rebootPending = $true
        break
    }
}

if ($rebootPending) {
    Write-Host "Reboot required. Restarting in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "No reboot required." -ForegroundColor Green
}
