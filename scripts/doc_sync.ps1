param(
    [ValidateSet('Start', 'Stop', 'Status', 'Worker')]
    [string]$Action = 'Status',
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw '기본 설정 경로를 계산할 수 없습니다. -ConfigPath를 지정하세요.'
    }
    $script:DefaultRoot = Split-Path -Parent $PSScriptRoot
    $ConfigPath = Join-Path $script:DefaultRoot '.local\doc-sync.json'
}
$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
$StateDirectory = Split-Path -Parent $ConfigPath
$LogPath = Join-Path $StateDirectory 'doc-sync.log'
$PidPath = Join-Path $StateDirectory 'doc-sync.pid'
$StopPath = Join-Path $StateDirectory 'doc-sync.stop'
$MutexName = 'Local\AigameDocSync_' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ConfigPath)).TrimEnd('=').Replace('+', 'A').Replace('/', 'B')

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Read-Config {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "로컬 설정 파일이 없습니다: $ConfigPath"
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $config.SourceRoot -or -not $config.SharePath) {
        throw '설정에 SourceRoot와 SharePath가 필요합니다.'
    }
    if (-not $config.IntervalSeconds) { $config | Add-Member -NotePropertyName IntervalSeconds -NotePropertyValue 60 -Force }
    if (-not $config.DebounceMilliseconds) { $config | Add-Member -NotePropertyName DebounceMilliseconds -NotePropertyValue 700 -Force }
    $config.SourceRoot = [IO.Path]::GetFullPath([string]$config.SourceRoot)
    $config.SharePath = [IO.Path]::GetFullPath([string]$config.SharePath)
    return $config
}

function Get-Mappings($Config) {
    @(
        @{ Source = (Join-Path $Config.SourceRoot 'AGENTS.md'); Destination = (Join-Path $Config.SharePath 'AGENTS.md') },
        @{ Source = (Join-Path $Config.SourceRoot 'docs\game_design.md'); Destination = (Join-Path $Config.SharePath 'game_design.md') },
        @{ Source = (Join-Path $Config.SourceRoot 'docs\status.md'); Destination = (Join-Path $Config.SharePath 'status.md') },
        @{ Source = (Join-Path $Config.SourceRoot 'docs\devlog.md'); Destination = (Join-Path $Config.SharePath 'devlog.md') }
    )
}

function Sync-One($Mapping) {
    if (-not (Test-Path -LiteralPath $Mapping.Source -PathType Leaf)) {
        Write-Log "원본이 없어 건너뜀(복사본은 삭제하지 않음): $($Mapping.Source)"
        return
    }
    $lastError = $null
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $sourceHash = (Get-FileHash -LiteralPath $Mapping.Source -Algorithm SHA256).Hash
            $destinationHash = $null
            if (Test-Path -LiteralPath $Mapping.Destination -PathType Leaf) {
                $destinationHash = (Get-FileHash -LiteralPath $Mapping.Destination -Algorithm SHA256).Hash
            }
            if ($sourceHash -eq $destinationHash) { return }
            Copy-Item -LiteralPath $Mapping.Source -Destination $Mapping.Destination -Force
            $verifiedHash = (Get-FileHash -LiteralPath $Mapping.Destination -Algorithm SHA256).Hash
            if ($verifiedHash -ne $sourceHash) { throw '복사 후 SHA-256 해시가 일치하지 않습니다.' }
            Write-Log "복사 완료: $([IO.Path]::GetFileName($Mapping.Destination))"
            return
        }
        catch {
            $lastError = $_.Exception.Message
            if ($attempt -lt 4) { Start-Sleep -Milliseconds (250 * [Math]::Pow(2, $attempt - 1)) }
        }
    }
    Write-Log "복사 실패(4회 시도): $([IO.Path]::GetFileName($Mapping.Destination)); $lastError"
}

function Sync-All($Config) {
    foreach ($mapping in (Get-Mappings $Config)) { Sync-One $mapping }
}

function Get-RunningProcessId {
    if (-not (Test-Path -LiteralPath $PidPath -PathType Leaf)) { return $null }
    try { $candidate = [int](Get-Content -LiteralPath $PidPath -Raw) } catch { return $null }
    $process = Get-Process -Id $candidate -ErrorAction SilentlyContinue
    if ($process) { return $candidate }
    Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
    return $null
}

switch ($Action) {
    'Status' {
        $runningId = Get-RunningProcessId
        if ($runningId) { Write-Output "실행 중 (PID $runningId). 로그: $LogPath" }
        else { Write-Output "중지됨. 로그: $LogPath" }
        exit 0
    }
    'Stop' {
        $runningId = Get-RunningProcessId
        if (-not $runningId) { Write-Output '실행 중인 동기화 프로그램이 없습니다.'; exit 0 }
        New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
        Set-Content -LiteralPath $StopPath -Value 'stop' -Encoding ASCII
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 250
            if (-not (Get-Process -Id $runningId -ErrorAction SilentlyContinue)) { break }
        }
        if (Get-Process -Id $runningId -ErrorAction SilentlyContinue) {
            Write-Output "중지 요청을 보냈지만 PID $runningId가 아직 종료되지 않았습니다. 로그를 확인하세요: $LogPath"
            exit 1
        }
        Write-Output '동기화 프로그램을 중지했습니다.'
        exit 0
    }
    'Start' {
        $runningId = Get-RunningProcessId
        if ($runningId) { Write-Output "이미 실행 중입니다 (PID $runningId)."; exit 0 }
        $null = Read-Config
        New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
        Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
        $hostExe = Join-Path $PSHOME 'powershell.exe'
        $scriptPath = $PSCommandPath
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $scriptPath = Join-Path $PSScriptRoot 'doc_sync.ps1' }
            else { $scriptPath = Join-Path (Split-Path -Parent $StateDirectory) 'scripts\doc_sync.ps1' }
        }
        $scriptPath = $scriptPath.Replace("'", "''")
        $configLiteral = $ConfigPath.Replace("'", "''")
        $workerCommand = "& ([scriptblock]::Create([IO.File]::ReadAllText('$scriptPath'))) -Action Worker -ConfigPath '$configLiteral'"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($workerCommand))
        $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + $encodedCommand
        $process = Start-Process -FilePath $hostExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 250
            $runningId = Get-RunningProcessId
            if ($runningId) { Write-Output "시작됨 (PID $runningId). 로그: $LogPath"; exit 0 }
            if ($process.HasExited) { break }
        }
        Write-Output "시작 상태를 확인하지 못했습니다. 로그와 설정을 확인하세요: $LogPath"
        exit 1
    }
    'Worker' {
        New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
        $mutex = New-Object Threading.Mutex($false, $MutexName)
        $ownsMutex = $false
        try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
        if (-not $ownsMutex) { Write-Log '중복 실행 요청을 종료함.'; exit 0 }
        try {
            Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $PidPath -Value $PID -Encoding ASCII
            $config = Read-Config
            Write-Log '시작됨. 초기 대조를 수행함.'
            Sync-All $config
            $watchers = New-Object System.Collections.ArrayList
            $sourceFolders = @((Join-Path $config.SourceRoot '.'), (Join-Path $config.SourceRoot 'docs'))
            foreach ($folder in $sourceFolders) {
                if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "감시할 원본 폴더가 없습니다: $folder" }
                $watcher = New-Object IO.FileSystemWatcher
                $watcher.Path = $folder
                $watcher.Filter = '*.md'
                $watcher.IncludeSubdirectories = $false
                $watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, Size'
                $watcher.EnableRaisingEvents = $true
                foreach ($eventName in @('Changed', 'Created', 'Renamed')) {
                    Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier ("DocSync_{0}_{1}" -f $watchers.Count, $eventName) | Out-Null
                }
                [void]$watchers.Add($watcher)
            }
            $pending = @{}
            $nextReconcile = (Get-Date).AddSeconds([int]$config.IntervalSeconds)
            while (-not (Test-Path -LiteralPath $StopPath)) {
                foreach ($event in @(Get-Event | Where-Object { $_.SourceIdentifier -like 'DocSync_*' })) {
                    $fullPath = $event.SourceEventArgs.FullPath
                    if ($event.SourceEventArgs -is [IO.RenamedEventArgs]) { $fullPath = $event.SourceEventArgs.FullPath }
                    $pending[$fullPath] = Get-Date
                    Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
                }
                $now = Get-Date
                foreach ($path in @($pending.Keys)) {
                    if (($now - $pending[$path]).TotalMilliseconds -ge [int]$config.DebounceMilliseconds) {
                        foreach ($mapping in (Get-Mappings $config)) {
                            if ([string]::Equals($path, $mapping.Source, [StringComparison]::OrdinalIgnoreCase)) { Sync-One $mapping }
                        }
                        $pending.Remove($path)
                    }
                }
                if ($now -ge $nextReconcile) {
                    Write-Log '주기적 대조를 수행함.'
                    Sync-All $config
                    $nextReconcile = $now.AddSeconds([int]$config.IntervalSeconds)
                }
                Start-Sleep -Milliseconds 250
            }
            Write-Log '중지 요청을 확인해 종료함.'
        }
        catch { Write-Log "실행 오류: $($_.Exception.Message)"; exit 1 }
        finally {
            Get-Event | Where-Object { $_.SourceIdentifier -like 'DocSync_*' } | Remove-Event -ErrorAction SilentlyContinue
            Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like 'DocSync_*' } | Unregister-Event -ErrorAction SilentlyContinue
            foreach ($watcher in $watchers) { $watcher.Dispose() }
            Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
            if ($ownsMutex) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
        exit 0
    }
}
