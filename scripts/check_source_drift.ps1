param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = "D:\Bubble"
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot

function Get-SharedFileHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash($stream)
        return ([BitConverter]::ToString($bytes)).Replace("-", "")
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

$mappings = @(
    [pscustomobject]@{
        Source = "策划\配置表\剧情、事件AI配置\剧情配置说明_给AI使用.md"
        Snapshot = "references\story-event\剧情配置说明_给AI使用.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\剧情、事件AI配置\事件配置说明_给AI使用.md"
        Snapshot = "references\story-event\事件配置说明_给AI使用.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\剧情、事件AI配置\剧情事件AI配置工作流.md"
        Snapshot = "references\story-event\剧情事件AI配置工作流.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\新手引导AI配置\新手引导AI配置工作流.md"
        Snapshot = "references\guide\新手引导AI配置工作流.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\新手引导AI配置\新手引导配置说明_给AI使用.md"
        Snapshot = "references\guide\新手引导配置说明_给AI使用.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\新手引导AI配置\新手引导配置说明_附录_现有链路索引.md"
        Snapshot = "references\guide\新手引导配置说明_附录_现有链路索引.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\新手引导AI配置\新手引导配置说明_附录_原表备忘页.md"
        Snapshot = "references\guide\新手引导配置说明_附录_原表备忘页.md"
    },
    [pscustomobject]@{
        Source = "策划\配置表\剧情、事件AI配置\剧情事件需求池.xlsx"
        Snapshot = "assets\templates\剧情事件需求池模板.xlsx"
    },
    [pscustomobject]@{
        Source = "策划\配置表\新手引导AI配置\新手引导需求填写模板.xlsx"
        Snapshot = "assets\templates\新手引导需求填写模板.xlsx"
    }
)

$results = foreach ($mapping in $mappings) {
    $sourcePath = Join-Path $ProjectRoot $mapping.Source
    $snapshotPath = Join-Path $skillRoot $mapping.Snapshot
    $sourceExists = Test-Path -LiteralPath $sourcePath -PathType Leaf
    $snapshotExists = Test-Path -LiteralPath $snapshotPath -PathType Leaf

    $sourceHash = if ($sourceExists) { Get-SharedFileHash -LiteralPath $sourcePath } else { $null }
    $snapshotHash = if ($snapshotExists) { Get-SharedFileHash -LiteralPath $snapshotPath } else { $null }

    $status = if (-not $sourceExists) {
        "source_missing"
    } elseif (-not $snapshotExists) {
        "snapshot_missing"
    } elseif ($sourceHash -eq $snapshotHash) {
        "current"
    } else {
        "drift"
    }

    [pscustomobject]@{
        source = $mapping.Source
        snapshot = $mapping.Snapshot
        status = $status
        source_sha256 = $sourceHash
        snapshot_sha256 = $snapshotHash
    }
}

$overallStatus = if (@($results | Where-Object { $_.status -ne "current" }).Count -eq 0) {
    "current"
} else {
    "drift"
}

[pscustomobject]@{
    skill = "bubble-story-event-guide-config"
    project_root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    overall_status = $overallStatus
    files = @($results)
} | ConvertTo-Json -Depth 5
