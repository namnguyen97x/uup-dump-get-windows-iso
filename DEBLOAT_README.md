# Windows ISO Debloat Workflow - Complete Fix

## Overview
This GitHub Actions workflow automatically downloads Windows ISO files (either from workflow artifacts or direct links), removes bloatware, applies registry tweaks, and creates a debloated ISO ready for installation.

## Recent Fixes and Improvements

### 🔧 Major Issues Fixed

#### 1. **Install.ESD Detection and Conversion**
- **Problem**: Script failed when ISO contained `install.esd` instead of `install.wim`
- **Fix**: Added automatic detection of `install.esd` and conversion to `install.wim`
- **Methods**: Uses `wimlib-imagex` with fallback to `dism /export-image`

#### 2. **WIM Image Counting**
- **Problem**: Incorrect grep pattern `"Image Index"` instead of `"Index:"`
- **Fix**: Updated pattern to correctly count images using `Select-String "Index:"`
- **Result**: Proper detection of available Windows editions

#### 3. **ISO Rebuilding**
- **Problem**: Script was incomplete - missing ISO rebuilding functionality
- **Fix**: Added complete ISO rebuilding with multiple fallback methods:
  - Primary: `oscdimg` (Windows SDK tool)
  - Secondary: PowerShell `New-IsoFile` (Windows 10/11 built-in)
  - Tertiary: `7-Zip` with manual ISO creation

#### 4. **Permission Issues**
- **Problem**: Permission denied when writing boot files during ISO rebuild
- **Fix**: Added ownership change to current user before ISO creation
- **Code**: `Set-Acl` with `FullControl` permissions

#### 5. **Error Handling and Debugging**
- **Problem**: Insufficient error information and debugging
- **Fix**: Added comprehensive logging throughout the entire process:
  - Parameter validation
  - Tool availability checks
  - Step-by-step progress reporting
  - Detailed error messages with stack traces
  - Exit code reporting for all commands

### 🚀 Workflow Improvements

#### 1. **Enhanced Download Process**
- **Auto-detection**: Automatically detects workflow URLs vs direct links
- **Robust downloading**: Multiple download methods with fallbacks
- **Progress tracking**: Better download progress and verification
- **Cleanup**: Automatic cleanup of temporary files

#### 2. **Tool Availability Checks**
- **Required tools**: `dism`, `robocopy`, `reg`
- **Optional tools**: `oscdimg`, `wimlib-imagex`, `7z`
- **Graceful degradation**: Uses alternative methods when tools unavailable

#### 3. **Comprehensive Validation**
- **Input validation**: Checks ISO file existence and size
- **Disk space monitoring**: Warns if insufficient space
- **Output verification**: Confirms successful ISO creation
- **File integrity**: Validates downloaded and created files

### 📋 What Gets Removed

#### Windows Store Apps
- Microsoft Bing News
- Microsoft Bing Weather  
- Microsoft Windows Alarms
- Microsoft Windows Feedback Hub
- Microsoft Get Help
- Microsoft Get Started
- Microsoft Windows Maps
- Microsoft Windows Communications Apps
- Microsoft Zune Music
- Microsoft Zune Video
- Microsoft Xbox Apps
- Microsoft People
- Microsoft Your Phone
- Microsoft Skype App
- Microsoft Todos
- Microsoft Wallet

#### System Components
- **OneDrive**: Complete removal of OneDrive setup files
- **Microsoft Edge**: Full removal of Edge browser
- **Windows Capabilities**:
  - Steps Recorder
  - Handwriting recognition
  - OCR (Optical Character Recognition)
  - Speech recognition
  - Text-to-speech
  - WordPad
  - Math Recognizer
  - Windows Media Player
  - PowerShell ISE

#### Windows Features
- Internet Explorer (Optional Package)
- Language Features (Handwriting, OCR, Speech, Text-to-Speech)
- WordPad (Feature on Demand)
- Media Player Package
- Tablet PC Math Package
- Steps Recorder Package

### 🔧 Registry Tweaks Applied

#### Windows 11 Bypass
- **TPM Check Bypass**: `BypassTPMCheck = 1`
- **Secure Boot Bypass**: `BypassSecureBootCheck = 1`

### 🛠️ Technical Details

#### Supported Input Formats
1. **GitHub Workflow URL**: `https://github.com/user/repo/actions/runs/123456789`
2. **Direct Download Link**: Any direct ISO download URL

#### ISO Creation Methods
1. **oscdimg** (Preferred):
   ```powershell
   oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"boot\etfsboot.com"#pEF,e,b"efi\microsoft\boot\efisys.bin" source output.iso
   ```

2. **PowerShell New-IsoFile** (Fallback):
   ```powershell
   New-IsoFile -Source $source -Path $output -BootFile "boot\etfsboot.com" -Media DVDROM
   ```

3. **7-Zip** (Last resort):
   ```powershell
   7z a -tiso output.iso source\*
   ```

#### File Structure
```
.github/workflows/
├── debloat.yml          # Main workflow file
scripts/
├── debloat-windows-iso.ps1  # Core debloat script
```

### 📊 Performance Optimizations

#### Memory Management
- Automatic cleanup of temporary directories
- Proper unmounting of WIM images
- Efficient file copying with robocopy

#### Disk Space
- Monitors available disk space
- Warns if less than 20GB available
- Estimates required space for operations

#### Parallel Processing
- Uses robocopy with `/MT:8` for parallel file copying
- Optimized for multi-core systems

### 🔍 Debugging Features

#### Comprehensive Logging
- Step-by-step progress reporting
- Command output capture
- Exit code reporting
- Error stack traces
- File existence checks
- Directory listing at key points

#### Validation Points
- ISO file verification after download
- WIM image count validation
- Mount directory verification
- Output ISO creation confirmation
- File size reporting

### 🚨 Error Recovery

#### Graceful Degradation
- Multiple fallback methods for each operation
- Continues processing even if some components fail
- Provides detailed error information for troubleshooting

#### Cleanup on Failure
- Automatic cleanup of temporary files
- Proper unmounting even on errors
- Preserves original files

### 📝 Usage Instructions

#### 1. Manual Workflow Trigger
1. Go to Actions tab in your repository
2. Select "Debloat Windows ISO" workflow
3. Click "Run workflow"
4. Enter either:
   - GitHub workflow URL: `https://github.com/user/repo/actions/runs/123456789`
   - Direct ISO download link: `https://example.com/windows.iso`
5. Click "Run workflow"

#### 2. Local Execution
```powershell
# Run as Administrator
.\scripts\debloat-windows-iso.ps1 -isoPath "windows.iso" -outputISO "debloated-windows.iso"
```

### 🔧 Troubleshooting

#### Common Issues

1. **"No artifacts found"**
   - Ensure source workflow has uploaded artifacts
   - Check artifact names contain "iso"

2. **"Permission denied"**
   - Run as Administrator
   - Check file ownership and permissions

3. **"Not enough disk space"**
   - Ensure at least 20GB free space
   - Clean up temporary files

4. **"Tool not found"**
   - Script will use alternative methods
   - Check tool availability in environment

#### Debug Information
- All commands output detailed logs
- Check GitHub Actions logs for specific error messages
- Verify file paths and permissions

### 📈 Future Improvements

#### Planned Enhancements
- Support for multiple Windows editions in single run
- Custom debloat profiles
- Integration with Windows Update removal
- Additional registry optimizations
- Performance benchmarking

#### Community Contributions
- Custom app removal lists
- Additional registry tweaks
- Alternative ISO creation methods
- Language-specific optimizations

---

## License
This project is open source. Feel free to contribute improvements and fixes.

## Support
For issues and questions, please create an issue in the repository with detailed logs and error messages. 