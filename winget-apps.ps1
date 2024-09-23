<#PSScriptInfo

.VERSION 0.0.1

.GUID 3b581edb-5d90-4fa1-ba15-4f2377275463

.AUTHOR asaikovski@outl;ook.com

.TAGS PowerShell Windows winget installer 

.PROJECTURI https://github.com/AaronSaikovski/winget-app-install

.DESCRIPTION Downloads and installs the latest version of winget and its dependencies - This  should be run with administrative privileges.

.RELEASENOTES
[Version 0.0.1] - Initial Release.
#>

#Requires -RunAsAdministrator
# needs this - set-executionpolicy bypass -Force 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# REF: https://github.com/asheroto/winget-install/blob/master/winget-install.ps1
# https://github.com/Kugane/winget/blob/main/winget-basic.ps1


# Main App list
$apps = @(
    "7zip.7zip"
    "Foxit.FoxitReader"
    "Google.Chrome"
    "Mozilla.Firefox"
   	"SublimeHQ.SublimeText.4"
   	"Notepad++.Notepad++"
   	"Git.Git"
   	"Microsoft.VisualStudioCode"
   	"Microsoft.AzureCLI"
   	"Microsoft.Azure.AZCopy.10"
   	"Microsoft.PowerToys"
    "Microsoft.PCManager"
   	"Microsoft.VisualStudio.2022.Professional"
);

# other apps
$other_apps = @(
    "Microsoft.PowerShell"
    "dotPDN.PaintDotNet" 
    "Microsoft.Azd"
    "DevToys-app.DevToys"
    "Microsoft.Todos"
    "Microsoft.Office"
);

####################################################

# checks for execution with administrator privileges
function check_rights {
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "The script needs to be executed with administrator privileges."
        Break
    }
}

####################################################

### Get List of installed Apps ###
function get_list {
    Clear-Host
    $newPath = ("$DesktopPath\applist_$env:COMPUTERNAME" + "_" + $(Get-Date -Format 'yyyy_MM_dd') + ".txt")
    Write-Host -ForegroundColor Yellow "Generating Applist..."
    winget list > $newPath
    Write-Host -ForegroundColor Magenta "List saved in $newPath"
}

####################################################

### update/Install WinGet ###
function install_winget {

    # Idea from this gist: https://gist.github.com/crutkas/6c2096eae387e544bd05cde246f23901
    $hasPackageManager = Get-AppxPackage -Name 'Microsoft.Winget.Source' | Select Name, Version
    $hasVCLibs = Get-AppxPackage -Name 'Microsoft.VCLibs.140.00.UWPDesktop' | Select Name, Version
    $hasXAML = Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.7*' | Select Name, Version
    $hasAppInstaller = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Select Name, Version
    $DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    $errorlog = "$DesktopPath\winget_error.log"

    Clear-Host
    Write-Host -ForegroundColor Yellow "Checking if WinGet is installed"
    if (!$hasPackageManager) {
        if ($hasVCLibs.Version -lt "14.0.30035.0") {
            Write-Host -ForegroundColor Yellow "Installing VCLibs dependencies..."
            Add-AppxPackage -Path "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
            Write-Host -ForegroundColor Green "VCLibs dependencies successfully installed."
        }
        else {
            Write-Host -ForegroundColor Green "VCLibs is already installed. Skip..."
        }
        if ($hasXAML.Version -lt "7.2203.17001.0") {
            Write-Host -ForegroundColor Yellow "Installing XAML dependencies..."
            Add-AppxPackage -Path "https://github.com/Kugane/winget/raw/main/Microsoft.UI.Xaml.2.7_7.2203.17001.0_x64__8wekyb3d8bbwe.Appx"
            Write-Host -ForegroundColor Green "XAML dependencies successfully installed."
        }
        else {
            Write-Host -ForegroundColor Green "XAML is already installed. Skip..."
        }
        if ($hasAppInstaller.Version -lt "1.16.12653.0") {
            Write-Host -ForegroundColor Yellow "Installing WinGet..."
            $releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13
            $releases = Invoke-RestMethod -Uri "$($releases_url)"
            $latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith("msixbundle") } | Select-Object -First 1
            Add-AppxPackage -Path $latestRelease.browser_download_url
            Write-Host -ForegroundColor Green "WinGet successfully installed."
        }
    }
    else {
        Write-Host -ForegroundColor Green "WinGet is already installed. Skip..."
        Write-Host ""
    }
    Pause
}


####################################################

### Install Apps silent ###
function install_silent {
    Clear-Host
    Write-Host -ForegroundColor Cyan "Installing new Apps"
    Foreach ($app in $apps) {
        $listApp = winget list --exact --accept-source-agreements -q $app
        if (![String]::Join("", $listApp).Contains($app)) {
            Write-Host -ForegroundColor Yellow  "Install:" $app
            # MS Store apps
            if ((winget search --exact -q $app) -match "msstore") {
                winget install --exact --silent --accept-source-agreements --accept-package-agreements $app --source msstore
            }
            # All other Apps
            else {
                winget install --exact --silent --scope machine --accept-source-agreements --accept-package-agreements $app
            }
            if ($LASTEXITCODE -eq 0) {
                Write-Host -ForegroundColor Green "$app successfully installed."
            }
            else {
                $app + " couldn't be installed." | Add-Content $errorlog
                Write-Warning "$app couldn't be installed."
                Write-Host -ForegroundColor Yellow "Write in $errorlog"
                Pause
            }  
        }
        else {
            Write-Host -ForegroundColor Yellow "$app already installed. Skip..."
        }
    }
    Pause
}

####################################################

# installs other apps
function install-other-apps {
    Clear-Host
    Write-Host -ForegroundColor Cyan "Installing Other Apps"
    Foreach ($app in $other_apps) {
        $listApp = winget list --exact --accept-source-agreements -q $app
        if (![String]::Join("", $listApp).Contains($app)) {
            Write-Host -ForegroundColor Yellow  "Install:" $app
       
            # install apps
            winget install --exact --silent --scope machine --accept-source-agreements --accept-package-agreements --id $app

            if ($LASTEXITCODE -eq 0) {
                Write-Host -ForegroundColor Green "$app successfully installed."
            }
            else {
                $app + " couldn't be installed." | Add-Content $errorlog
                Write-Warning "$app couldn't be installed."
                Write-Host -ForegroundColor Yellow "Write in $errorlog"
                Pause
            }  
        }
        else {
            Write-Host -ForegroundColor Yellow "$app already installed. Skip..."
        }
    }
    Pause
}

####################################################

### Finished ###
function finish {
    
    # update all packages
    winget update --all --include-unknown

    Write-Host
    Write-Host -ForegroundColor Magenta  "Installation finished"
    Write-Host
    Pause
}

####################################################

# MAIN
check_rights
install_winget
install_silent
install-other-apps
finish

####################################################