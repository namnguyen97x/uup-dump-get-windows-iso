# Simple Windows ISO Debloat Script
# Fallback option for basic debloating without mounting

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$IsVerbose,
    
    [Parameter(Mandatory=$false)]
    [string]$WindowsVersion = "11"
)

# Cấu hình logging
$LogFile = Join-Path $OutputPath "simple-debloat.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($IsVerbose) {
        Write-Host $logMessage
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

try {
    Write-Log "Starting simple Windows ISO debloat process..."
    Write-Log "Input Path: $InputPath"
    Write-Log "Output Path: $OutputPath"
    Write-Log "Windows Version: $WindowsVersion"
    
    # Tạo thư mục output nếu chưa tồn tại
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Kiểm tra thư mục input
    if (!(Test-Path $InputPath)) {
        throw "Input directory not found: $InputPath"
    }
    
    # Tìm file ISO trong thư mục input
    $isoFiles = Get-ChildItem -Path $InputPath -Filter "*.iso" -Recurse
    if ($isoFiles.Count -eq 0) {
        throw "No ISO files found in input directory: $InputPath"
    }
    
    $isoFile = $isoFiles[0]
    Write-Log "Found ISO file: $($isoFile.Name)"
    
    # Copy ISO file
    Write-Log "Copying ISO file from $InputPath to $OutputPath"
    $outputIsoPath = Join-Path $OutputPath $isoFile.Name
    Copy-Item -Path $isoFile.FullName -Destination $outputIsoPath -Force
    Write-Log "Successfully copied ISO file: $($isoFile.Name)"
    
    # Tạo file unattend.xml
    $unattendPath = Join-Path $OutputPath "unattend.xml"
    $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
            <TimeZone>UTC</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <AdministratorPassword>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <AutoLogon>
                <Password>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
            </AutoLogon>
        </component>
    </settings>
</unattend>
"@
    
    $unattendContent | Out-File -FilePath $unattendPath -Encoding UTF8
    Write-Log "Created unattend.xml file"
    
    # Tạo file autounattend.xml
    $autounattendPath = Join-Path $OutputPath "autounattend.xml"
    $autounattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Size>100</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>System</Label>
                            <Format>NTFS</Format>
                            <Active>true</Active>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Format>NTFS</Format>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>2</PartitionID>
                    </InstallTo>
                    <InstallToAvailablePartition>false</InstallToAvailablePartition>
                    <WillShowUI>OnError</WillShowUI>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/NAME</Key>
                            <Value>Windows $WindowsVersion</Value>
                        </MetaData>
                    </InstallFrom>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>*</ComputerName>
            <TimeZone>UTC</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <AdministratorPassword>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <AutoLogon>
                <Password>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
            </AutoLogon>
        </component>
    </settings>
</unattend>
"@
    
    $autounattendContent | Out-File -FilePath $autounattendPath -Encoding UTF8
    Write-Log "Created autounattend.xml file"
    
    # Tạo file thông tin về ISO đã được debloat
    $isoInfo = @{
        OriginalFile = $isoFile.Name
        DebloatDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        WindowsVersion = $WindowsVersion
        DebloatType = "Simple (No mounting)"
        FeaturesAdded = @(
            "Unattended setup",
            "OOBE bypass",
            "Auto-login as Administrator"
        )
    }
    
    $infoFile = Join-Path $OutputPath "debloat-info.json"
    $isoInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath $infoFile -Encoding UTF8
    Write-Log "Created debloat info file"
    
    Write-Log "Simple debloat process completed successfully!"
    Write-Host "Simple debloat completed successfully!" -ForegroundColor Green
    Write-Host "Output files in: $OutputPath" -ForegroundColor Green
    exit 0
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Log "ERROR: $errorMessage"
    Write-Host "Simple debloat failed! Error: $errorMessage" -ForegroundColor Red
    exit 1
} 