# Artifact Manager Script
# Script để quản lý và tải artifacts từ GitHub Actions

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$WorkflowUrl = "",
    [Parameter(Mandatory=$false)]
    [string]$Repository = "",
    [Parameter(Mandatory=$false)]
    [string]$Token = "",
    [Parameter(Mandatory=$false)]
    [string]$Pattern = "Windows-*",
    [Parameter(Mandatory=$false)]
    [int]$MaxRuns = 10,
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./artifacts",
    [Parameter(Mandatory=$false)]
    [switch]$ListOnly,
    [Parameter(Mandatory=$false)]
    [switch]$DownloadLatest,
    [Parameter(Mandatory=$false)]
    [string]$WorkflowRunId = "",
    [Parameter(Mandatory=$false)]
    [string]$ArtifactName = "",
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($Verbose) {
        Write-Host $logMessage
    }
}

function Get-GitHubToken {
    # Thử lấy token từ các nguồn khác nhau
    if ($Token) {
        return $Token
    }
    
    # Thử từ environment variable
    $envToken = $env:GITHUB_TOKEN
    if ($envToken) {
        return $envToken
    }
    
    # Thử từ GitHub CLI
    try {
        $ghToken = gh auth token 2>$null
        if ($ghToken) {
            return $ghToken
        }
    }
    catch {
        # Ignore error
    }
    
    return $null
}

function Get-RepositoryInfo {
    # Thử lấy thông tin repository từ các nguồn khác nhau
    if ($Repository) {
        return $Repository
    }
    
    # Thử từ environment variable
    $envRepo = $env:GITHUB_REPOSITORY
    if ($envRepo) {
        return $envRepo
    }
    
    # Thử từ git remote
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl) {
            # Convert SSH URL to HTTPS format
            $remoteUrl = $remoteUrl -replace "git@github\.com:", "https://github.com/"
            $remoteUrl = $remoteUrl -replace "\.git$", ""
            $repo = $remoteUrl -replace "https://github\.com/", ""
            return $repo
        }
    }
    catch {
        # Ignore error
    }
    
    return $null
}

function Get-Artifacts {
    param([string]$Repo, [string]$Token, [string]$Pattern, [int]$MaxRuns)
    
    try {
        Write-Log "Getting artifacts from repository: $Repo"
        
        $headers = @{
            'Authorization' = "token $Token"
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        # Lấy workflow runs gần đây
        $workflowRunsUrl = "https://api.github.com/repos/$Repo/actions/runs?per_page=$MaxRuns&status=completed&conclusion=success"
        $workflowRuns = Invoke-RestMethod -Uri $workflowRunsUrl -Headers $headers
        
        $allArtifacts = @()
        
        foreach ($run in $workflowRuns.workflow_runs) {
            Write-Log "Checking workflow run: $($run.id) - $($run.name)"
            
            # Lấy artifacts từ mỗi workflow run
            $artifactsUrl = "https://api.github.com/repos/$Repo/actions/runs/$($run.id)/artifacts"
            try {
                $artifacts = Invoke-RestMethod -Uri $artifactsUrl -Headers $headers
                
                foreach ($artifact in $artifacts.artifacts) {
                    if ($artifact.name -like $Pattern) {
                        $artifactInfo = @{
                            name = $artifact.name
                            workflow_run_id = $run.id
                            workflow_name = $run.name
                            workflow_id = $run.workflow_id
                            created_at = $artifact.created_at
                            updated_at = $artifact.updated_at
                            size = $artifact.size_in_bytes
                            download_url = $artifact.archive_download_url
                        }
                        $allArtifacts += $artifactInfo
                        Write-Log "Found artifact: $($artifact.name) from workflow: $($run.name)"
                    }
                }
            }
            catch {
                Write-Log "Failed to get artifacts from run $($run.id): $($_.Exception.Message)" "WARN"
            }
        }
        
        return $allArtifacts
    }
    catch {
        Write-Log "Failed to get workflow runs: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Download-Artifact {
    param([object]$Artifact, [string]$OutputPath, [string]$Token)
    
    try {
        Write-Log "Downloading artifact: $($Artifact.name) from workflow: $($Artifact.workflow_name)"
        
        # Tạo thư mục output
        if (!(Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Tạo thư mục cho artifact cụ thể
        $artifactPath = Join-Path $OutputPath $Artifact.name
        if (!(Test-Path $artifactPath)) {
            New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
        }
        
        # Download artifact sử dụng GitHub CLI
        $result = gh run download $Artifact.workflow_run_id --name $Artifact.name --dir $artifactPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully downloaded artifact: $($Artifact.name)" "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to download artifact: $($Artifact.name)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error downloading artifact: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Download-SpecificArtifact {
    param([string]$WorkflowRunId, [string]$ArtifactName, [string]$OutputPath)
    
    try {
        Write-Log "Downloading specific artifact: $ArtifactName from run: $WorkflowRunId"
        
        # Tạo thư mục output
        if (!(Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Download artifact sử dụng GitHub CLI
        $result = gh run download $WorkflowRunId --name $ArtifactName --dir $OutputPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully downloaded artifact: $ArtifactName" "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to download artifact: $ArtifactName" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error downloading specific artifact: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Download-Artifact-From-WorkflowUrl {
    param([string]$WorkflowUrl, [string]$OutputPath)
    # Parse repo and run_id from URL
    if ($WorkflowUrl.StartsWith("@")) { $WorkflowUrl = $WorkflowUrl.Substring(1) }
    if ($WorkflowUrl -match 'github.com/([^/]+/[^/]+)/actions/runs/([0-9]+)') {
        $repo = $Matches[1]
        $runId = $Matches[2]
        Write-Host "Detected repo: $repo, run_id: $runId" -ForegroundColor Cyan
        $token = Get-GitHubToken
        $headers = @{'Authorization' = "token $token"; 'Accept' = 'application/vnd.github.v3+json'}
        $artifactsUrl = "https://api.github.com/repos/$repo/actions/runs/$runId/artifacts"
        $artifacts = Invoke-RestMethod -Uri $artifactsUrl -Headers $headers
        if ($artifacts.artifacts.Count -eq 0) {
            Write-Host "No artifact found in workflow run." -ForegroundColor Yellow
            exit 1
        }
        $artifactName = $artifacts.artifacts[0].name
        Write-Host "Downloading artifact: $artifactName from run: $runId" -ForegroundColor Green
        if (!(Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $result = gh run download $runId --repo $repo --name $artifactName --dir $OutputPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully downloaded artifact: $artifactName" -ForegroundColor Green
        } else {
            Write-Host "Failed to download artifact: $artifactName" -ForegroundColor Red
            exit 1
        }
        exit 0
    } else {
        Write-Host "Invalid workflow run URL!" -ForegroundColor Red
        exit 1
    }
}

# Main execution
try {
    Write-Log "Starting Artifact Manager..." "INFO"
    
    # Lấy thông tin cần thiết
    $repo = Get-RepositoryInfo
    if (!$repo) {
        throw "Could not determine repository. Please specify -Repository parameter or run from a git repository."
    }
    
    $token = Get-GitHubToken
    if (!$token) {
        throw "Could not get GitHub token. Please specify -Token parameter or set GITHUB_TOKEN environment variable."
    }
    
    Write-Log "Repository: $repo" "INFO"
    Write-Log "Pattern: $Pattern" "INFO"
    Write-Log "Max Runs: $MaxRuns" "INFO"
    
    # Nếu chỉ liệt kê artifacts
    if ($ListOnly) {
        Write-Host "`n=== Available Artifacts ===" -ForegroundColor Cyan
        $artifacts = Get-Artifacts -Repo $repo -Token $token -Pattern $Pattern -MaxRuns $MaxRuns
        
        if ($artifacts.Count -eq 0) {
            Write-Host "No artifacts found matching pattern: $Pattern" -ForegroundColor Yellow
        } else {
            $artifacts | Sort-Object created_at -Descending | ForEach-Object {
                $sizeMB = [math]::Round($_.size / 1MB, 2)
                $createdDate = [DateTime]::Parse($_.created_at).ToString("yyyy-MM-dd HH:mm")
                Write-Host "  - $($_.name) (${sizeMB}MB)" -ForegroundColor White
                Write-Host "    Workflow: $($_.workflow_name)" -ForegroundColor Gray
                Write-Host "    Run ID: $($_.workflow_run_id)" -ForegroundColor Gray
                Write-Host "    Created: $createdDate" -ForegroundColor Gray
                Write-Host ""
            }
        }
        exit 0
    }
    
    # Nếu tải artifact cụ thể
    if ($WorkflowRunId -and $ArtifactName) {
        $success = Download-SpecificArtifact -WorkflowRunId $WorkflowRunId -ArtifactName $ArtifactName -OutputPath $OutputPath
        if ($success) {
            Write-Host "Successfully downloaded artifact: $ArtifactName" -ForegroundColor Green
        } else {
            Write-Host "Failed to download artifact: $ArtifactName" -ForegroundColor Red
            exit 1
        }
        exit 0
    }
    
    # Lấy danh sách artifacts
    $artifacts = Get-Artifacts -Repo $repo -Token $token -Pattern $Pattern -MaxRuns $MaxRuns
    
    if ($artifacts.Count -eq 0) {
        Write-Host "No artifacts found matching pattern: $Pattern" -ForegroundColor Yellow
        exit 0
    }
    
    # Sắp xếp theo thời gian tạo (mới nhất trước)
    $sortedArtifacts = $artifacts | Sort-Object created_at -Descending
    
    # Nếu tải artifact mới nhất
    if ($DownloadLatest) {
        $latestArtifact = $sortedArtifacts[0]
        Write-Host "Downloading latest artifact: $($latestArtifact.name)" -ForegroundColor Cyan
        
        $success = Download-Artifact -Artifact $latestArtifact -OutputPath $OutputPath -Token $token
        if ($success) {
            Write-Host "Successfully downloaded latest artifact: $($latestArtifact.name)" -ForegroundColor Green
        } else {
            Write-Host "Failed to download latest artifact: $($latestArtifact.name)" -ForegroundColor Red
            exit 1
        }
        exit 0
    }
    
    # Hiển thị danh sách artifacts để người dùng chọn
    Write-Host "`n=== Available Artifacts ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt [Math]::Min($sortedArtifacts.Count, 10); $i++) {
        $artifact = $sortedArtifacts[$i]
        $sizeMB = [math]::Round($artifact.size / 1MB, 2)
        $createdDate = [DateTime]::Parse($artifact.created_at).ToString("yyyy-MM-dd HH:mm")
        Write-Host "  [$i] $($artifact.name) (${sizeMB}MB)" -ForegroundColor White
        Write-Host "      Workflow: $($artifact.workflow_name)" -ForegroundColor Gray
        Write-Host "      Run ID: $($artifact.workflow_run_id)" -ForegroundColor Gray
        Write-Host "      Created: $createdDate" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Hỏi người dùng chọn artifact
    $choice = Read-Host "Enter artifact number to download (or 'q' to quit)"
    if ($choice -eq 'q' -or $choice -eq 'Q') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    $index = [int]$choice
    if ($index -ge 0 -and $index -lt $sortedArtifacts.Count) {
        $selectedArtifact = $sortedArtifacts[$index]
        Write-Host "Downloading artifact: $($selectedArtifact.name)" -ForegroundColor Cyan
        
        $success = Download-Artifact -Artifact $selectedArtifact -OutputPath $OutputPath -Token $token
        if ($success) {
            Write-Host "Successfully downloaded artifact: $($selectedArtifact.name)" -ForegroundColor Green
        } else {
            Write-Host "Failed to download artifact: $($selectedArtifact.name)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Log "Artifact Manager finished." "INFO"
}

# Main execution
if ($WorkflowUrl -or ($args.Count -gt 0 -and $args[0] -match 'github.com/.+/actions/runs/')) {
    $url = $WorkflowUrl
    if (-not $url) { $url = $args[0] }
    Download-Artifact-From-WorkflowUrl -WorkflowUrl $url -OutputPath $OutputPath
    exit 0
} 