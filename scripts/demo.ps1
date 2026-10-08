# Commands for the 4 demo scenarios. Run ONE step at a time, from any folder:
#   .\scripts\demo.ps1 1
#   .\scripts\demo.ps1 2a
#   .\scripts\demo.ps1 2b
#   .\scripts\demo.ps1 3
#   .\scripts\demo.ps1 3-observe
#   .\scripts\demo.ps1 4-fix
# If script execution is blocked: powershell -ExecutionPolicy Bypass -File .\scripts\demo.ps1 1
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("1", "2a", "2b", "3", "3-observe", "4-fix")]
    [string]$Step
)

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot
$Overlay = Join-Path $RepoRoot "k8s\overlays\dev\kustomization.yaml"

function Check {
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit code $LASTEXITCODE)" }
}

# Edit the overlay without adding a BOM or changing line endings
function Set-OverlayValue {
    param([string]$Pattern, [string]$Replacement)
    $text = [IO.File]::ReadAllText($Overlay)
    $new = [regex]::Replace($text, $Pattern, $Replacement)
    [IO.File]::WriteAllText($Overlay, $new, (New-Object System.Text.UTF8Encoding $false))
}

switch ($Step) {
    "1" {   # Continuous deployment: replicas 2 -> 4
        Set-OverlayValue '(?m)^([ \t]*count:)[^\r\n]*' '${1} 4'
        git commit -am "demo1: scale to 4 replicas"; Check
        git push; Check
    }
    "2a" {  # Drift: manual deletion
        kubectl delete deployment web -n demo; Check
    }
    "2b" {  # Drift: manual change
        kubectl scale deployment web -n demo --replicas=10; Check
    }
    "3" {   # Synced but not Healthy: image tag that does not exist
        Set-OverlayValue '(?m)^([ \t]*newTag:)[^\r\n]*' '${1} does-not-exist'
        git commit -am "demo3: bad image tag"; Check
        git push; Check
    }
    "3-observe" {
        kubectl get pods -n demo
        kubectl describe pod -n demo -l app=web | Select-String -Pattern "Failed|BackOff" -Context 0,2
    }
    "4-fix" {   # After the UI rollback: realign Git by reverting the bad commit
        git revert --no-edit HEAD; Check
        git push; Check
    }
}
