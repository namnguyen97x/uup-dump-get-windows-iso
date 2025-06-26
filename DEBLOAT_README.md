# Windows ISO Debloat Workflow

This repository contains a GitHub Actions workflow for debloating Windows ISO files to remove bloatware and create optimized installation media.

## Features

### 🔧 Two Debloat Methods

1. **Shell Script Method** (`debloat_windows.sh`)
   - Runs on Ubuntu Linux
   - Uses `wimtools`, `p7zip-full`, and `xorriso`
   - Actually removes AppX packages from the WIM image
   - Creates bootable ISO with reduced bloatware

2. **PowerShell Method** (`scripts/debloat-windows-iso.ps1`)
   - Runs on Windows
   - Creates unattended setup configuration
   - Generates telemetry disable registry files
   - Provides detailed debloat information

### 📥 Smart Input Detection

- **Single Input Field**: Only one field to fill - the source
- **Auto-Detection**: Automatically detects if it's a workflow URL or direct download link
- **Artifact Name**: Uses the actual artifact name for output file naming

## Usage

### GitHub Actions Workflow

1. Go to the **Actions** tab in this repository
2. Select **"Debloat Windows ISO"** workflow
3. Click **"Run workflow"**
4. Enter the source in the single input field:

#### For Workflow URL:
```
https://github.com/namnguyen97x/uup-dump-get-windows-iso/actions/runs/15851372572
```

#### For Direct Download URL:
```
https://example.com/windows11.iso
```

### Input Parameter

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `source` | Workflow URL or direct download link (auto-detected) | Yes | Example workflow URL |

### Auto-Detection Logic

The workflow automatically detects the source type:

- **Workflow URL**: Contains `github.com` and `/actions/runs/`
- **Direct URL**: Any other URL format

## Output

The workflow produces:

### Shell Script Output (Ubuntu)
- `debloated-{artifact_name}.iso` - Optimized Windows ISO with bloatware removed
- Bootable ISO ready for installation

### PowerShell Output (Windows)
- Original ISO file (copied)
- `unattend.xml` - Unattended setup configuration
- `telemetry-disable.reg` - Registry file to disable telemetry
- `debloat-info.json` - Detailed debloat information
- `README.md` - Usage instructions

## Removed Components

### AppX Packages (Shell Script)
- Cortana (`Microsoft.549981C3F5F10`)
- Bing News & Weather
- Get Help & Get Started
- People, Skype, Alarms & Clock
- Camera, Mail and Calendar
- Feedback Hub, Maps, Voice Recorder
- Xbox Apps
- Various Microsoft Store apps

### Windows Components (PowerShell)
- Internet Explorer Optional Package
- Media Player Package
- Tablet PC Math Package
- Speech TTS Package
- Speech Recognition Package

## Files Structure

```
uup-dump-get-windows-iso/
├── .github/workflows/
│   └── debloat.yml              # Main workflow file
├── scripts/
│   ├── debloat-windows-iso.ps1  # Advanced PowerShell script
│   └── simple-debloat.ps1       # Simple PowerShell script
├── debloat_windows.sh           # Shell script for Ubuntu
└── DEBLOAT_README.md           # This file
```

## Workflow Steps

1. **Setup**: Checkout repository and install tools
2. **Auto-Detect**: Determine source type (workflow URL or direct URL)
3. **Download**: Get ISO from detected source
4. **Process**: Run debloat script (shell or PowerShell)
5. **Output**: Upload debloated files as artifacts

## Requirements

### For Shell Script (Ubuntu)
- `wimtools` - Windows image manipulation
- `p7zip-full` - ISO extraction
- `xorriso` - ISO creation
- `jq` - JSON parsing for artifact names

### For PowerShell (Windows)
- PowerShell 5.0+
- Administrative privileges (for advanced operations)

## Troubleshooting

### Common Issues

1. **ISO not found**: Ensure the URL is accessible or artifact exists
2. **Permission denied**: Run PowerShell as Administrator
3. **Tool not found**: Check if required tools are installed
4. **Disk space**: Ensure sufficient space for ISO processing

### Logs

- Check workflow logs in GitHub Actions
- PowerShell scripts create detailed log files
- Shell script outputs progress to console

## Examples

### Example 1: Workflow URL
```
https://github.com/namnguyen97x/uup-dump-get-windows-iso/actions/runs/15851372572
```
- Automatically detects as workflow URL
- Downloads artifact from the specified run
- Uses artifact name for output file

### Example 2: Direct Download URL
```
https://isomicrosoft.com/download/12
```
- Automatically detects as direct URL
- Downloads ISO directly
- Uses filename from URL for output

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the workflow
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the workflow logs
2. Review the troubleshooting section
3. Create an issue in the repository 