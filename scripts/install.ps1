# Creates a local kind cluster and installs ArgoCD.
# Prerequisites: Docker Desktop (running), kind, kubectl
# Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

# Native commands do not throw on failure in PowerShell, so we check $LASTEXITCODE ourselves.
$ErrorActionPreference = "Continue"

function Check {
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit code $LASTEXITCODE)" }
}

foreach ($tool in "docker", "kind", "kubectl") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' not found in PATH. See README section 1."
    }
}

docker info | Out-Null
Check

# Cluster (skipped if it already exists)
$existing = kind get clusters 2>$null
if ($existing -notcontains "gitops") {
    kind create cluster --name gitops
    Check
} else {
    Write-Host "kind cluster 'gitops' already exists, reusing it."
}
kubectl config use-context kind-gitops
Check

# ArgoCD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
Check
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Check
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
Check

# Faster reconciliation for the demo (30 s instead of 3 min)
$patchFile = Join-Path $env:TEMP "argocd-cm-patch.json"
[IO.File]::WriteAllText($patchFile, '{"data":{"timeout.reconciliation":"30s"}}', (New-Object System.Text.UTF8Encoding $false))
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file $patchFile
Check
kubectl -n argocd rollout restart deploy/argocd-repo-server
Check
kubectl -n argocd rollout restart statefulset/argocd-application-controller
Check
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=120s
Check
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=120s
Check

$b64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
Check
$adminPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))

Write-Host ""
Write-Host "ArgoCD admin password: $adminPassword"
Write-Host ""
Write-Host "UI: run  kubectl -n argocd port-forward svc/argocd-server 8080:443"
Write-Host "then open https://localhost:8080 (user: admin)"
