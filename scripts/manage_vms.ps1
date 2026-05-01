param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('start', 'stop', 'status')]
    [string]$Action
)

$ResourceGroup = "RG-CIS-CASSANDRA"

# [Check if AZ CLI is installed and logged in]
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed or not in PATH."
    exit 1
}

switch ($Action) {
    'status' {
        Write-Host "Fetching status for all VMs in $ResourceGroup..." -ForegroundColor Cyan
        az vm list -d -g $ResourceGroup --query "[].{Name:name, Status:powerState, PublicIP:publicIps}" -o table
    }
    'start' {
        Write-Host "Starting all VMs in $ResourceGroup..." -ForegroundColor Yellow
        $ids = az vm list -g $ResourceGroup --query "[].id" -o tsv
        if ([string]::IsNullOrWhiteSpace($ids)) {
            Write-Host "No VMs found." -ForegroundColor Red
            return
        }
        az vm start --ids $ids
        Write-Host "All VMs have been started." -ForegroundColor Green
    }
    'stop' {
        Write-Host "Deallocating (stopping) all VMs in $ResourceGroup..." -ForegroundColor Yellow
        $ids = az vm list -g $ResourceGroup --query "[].id" -o tsv
        if ([string]::IsNullOrWhiteSpace($ids)) {
            Write-Host "No VMs found." -ForegroundColor Red
            return
        }
        az vm deallocate --ids $ids
        Write-Host "All VMs have been stopped and deallocated." -ForegroundColor Green
    }
}
