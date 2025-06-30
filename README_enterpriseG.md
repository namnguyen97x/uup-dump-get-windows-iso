# Windows 11 Enterprise G Auto Builder

Automated GitHub Actions builder for Windows 11 Enterprise G using UUP dump and Enterprise G customization.

## 🚀 Automated Build Process

This project uses GitHub Actions to automatically:
1. **Download** latest Windows 11 ISO from UUP dump
2. **Extract** WIM file from ISO
3. **Convert** Windows 11 Pro to Enterprise G using original Enterprise G logic
4. **Create** final compressed Enterprise G build

## 📋 How to Use

### Start a Build
1. Go to **Actions** tab in GitHub
2. Select **"Start Enterprise G Build"** workflow
3. Click **"Run workflow"**
4. Choose your options:
   - **Target Build**: 22631 (23H2), 26100 (24H2), etc.
   - **Enable Activation**: KMS38 activation scripts
   - **Remove Edge**: Remove Microsoft Edge

### Monitor Progress
The build process runs in 2 stages:
1. **"1. Extract WIM from ISO"** - Downloads and extracts WIM (3-4 hours)
2. **"2. Build Enterprise G ISO"** - Converts to Enterprise G (2-3 hours)

### Download Results
- Check **Releases** tab for final builds
- Or download from **Actions** → **Artifacts**

## 🛡️ Enterprise G Features

- **Government Edition**: Enhanced security and privacy
- **Telemetry Disabled**: All tracking and data collection removed
- **Consumer Features Removed**: No ads, suggestions, or unwanted apps  
- **Privacy Optimized**: Registry tweaks for maximum privacy
- **Optional Edge Removal**: Microsoft Edge can be removed
- **KMS38 Activation**: Permanent activation support

## 📦 Supported Builds

| Build | Version | Status |
|-------|---------|---------|
| 22000 | Windows 11 21H2 | ✅ Supported |
| 22621 | Windows 11 22H2 | ✅ Supported |
| 22631 | Windows 11 23H2 | ✅ Supported |
| 26100 | Windows 11 24H2 | ✅ Supported |

## 🔧 Build Architecture

```
GitHub Actions Workflow:
├── 1-extract-wim.yml        # Download ISO → Extract WIM
├── 2-build-enterpriseg.yml  # Process WIM → Enterprise G
└── build-enterpriseg.yml    # Trigger workflow

Enterprise G Processing:
├── Enterprise G/             # Original Enterprise G files
│   ├── Build without Copilot.ps1
│   ├── files/               # Required tools and scripts
│   └── config.ini           # Build configuration
└── uup-dump-get-windows-iso.ps1  # UUP dump integration
```

## ⚠️ Important Notes

- **Educational Purpose**: This is for educational and testing only
- **Microsoft Licensing**: Users responsible for licensing compliance  
- **GitHub Storage**: Large files are cleaned up automatically to save space
- **Build Time**: Complete process takes 5-7 hours
- **Disk Space**: Each workflow uses ~20-30GB temporarily

## 🔗 Based On

- **UUP Dump**: https://uupdump.net/
- **Original Enterprise G**: Fox Khang's Enterprise G builder
- **Windows ISO Builder**: docker-sstc/windows-iso-builder approach

## 📊 Workflow Status

Monitor build status in the Actions tab. Each workflow shows:
- ✅ **Success**: Build completed, check releases
- ❌ **Failed**: Check logs for errors  
- 🟡 **Running**: Build in progress
- ⏸️ **Queued**: Waiting to start

## 🔄 Workflow Details

### Workflow 1: Extract WIM (`1-extract-wim.yml`)
- Downloads Windows 11 ISO from UUP dump
- Mounts ISO and extracts install.wim
- Finds Pro edition index
- Uploads WIM as artifact
- Cleans up ISO to save space

### Workflow 2: Build Enterprise G (`2-build-enterpriseg.yml`)
- Downloads WIM from previous workflow artifact
- Executes **"Build without Copilot.ps1"** from Enterprise G folder
- Processes WIM according to Enterprise G specifications
- Creates compressed final build
- Uploads to releases and artifacts

### Trigger Workflow (`build-enterpriseg.yml`)
- Simple trigger to start the build process
- Accepts user inputs for customization
- Manages workflow orchestration

---

**🤖 Fully automated Windows 11 Enterprise G builds via GitHub Actions** 