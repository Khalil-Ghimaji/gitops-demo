# Poor man's "watch" for Windows: refreshes deployments and pods every second.
# Run in a dedicated terminal during the demo:  .\scripts\watch.ps1
while ($true) {
    Clear-Host
    Get-Date -Format "HH:mm:ss"
    kubectl get deploy,pods -n demo
    Start-Sleep -Seconds 1
}
