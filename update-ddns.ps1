[CmdletBinding()]
param(
    [string] $ConfigPath = "~/.ddns/config.json"
)

# Scheduled task command:
# pwsh -WindowStyle Hidden -ExecutionPolicy ByPass -NoProfile -NoLogo -Noninteractive -Command "C:\dev\ddns\update-ddns.ps1"

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$config = Get-Content $ConfigPath -ea Stop | ConvertFrom-Json -ea Stop
$config | Add-Member logPath "~/.ddns/output.log" -ea ignore
$config | Add-Member statusPath "~/.ddns/status.json" -ea ignore

function trace {
    param(
        [Parameter(Mandatory)]
        [string] $Message
    )
    $ts = "[$([System.DateTimeOffset]::Now.ToString('o'))] "
    Write-Host $ts -NoNewline -ForegroundColor Gray
    Write-Host $message
    "$ts$message" | Out-File -FilePath $config.logpath -Append -ea Ignore
}

$status = [ordered]@{}
if (Test-Path $config.statusPath) {
    try {
        $status = Get-Content $config.statusPath -ea Stop | ConvertFrom-Json -AsHashtable -Depth 64 -ea Stop
    }
    catch {
        trace "Error loading $($config.statusPath). Ignoring."
    }
}

trace 'Fetching IPv4 from https://api.ipify.org...'
$ip = Invoke-RestMethod -Uri https://api.ipify.org -ea Stop
trace "IPv4: $ip"

foreach ($record in $config.records) {
    try {
        trace "Updating $($record.hostname)..."
        $recordstatus = [ordered]@{
            timestamp  = [System.DateTimeOffset]::Now
            result     = $null
            lastUpdate = $status[$record.hostname].lastUpdate
        }

        if ($recordstatus.lastUpdate.ip -eq $ip) {
            trace "No change since last update on $($recordstatus.lastUpdate.time)"
            $recordstatus.result = 'unchanged'
            continue
        }
        $updateArgs = @{
            Method         = 'POST'
            Uri            = "https://domains.google.com/nic/update?hostname=$([uri]::EscapeDataString($record.hostname))&myip=$([uri]::EscapeDataString($ip))"
            Authentication = 'Basic'
            Credential     = [pscredential]::new($record.Username, (ConvertTo-SecureString $record.Password -AsPlainText -Force))
            Headers        = @{'user-agent' = 'update-ddns/1.0' }
        }
            
        trace "Updating DNS via $($updateArgs.Uri)"
        $response = Invoke-RestMethod @updateArgs -SkipHttpErrorCheck -ea SilentlyContinue
            
        if ($null -eq $response) {
            # an error occurred sending the request
            trace "Exception: $($Error[0].Exception)"
            $recordstatus.result = 'exception'
            $recordstatus.exception = $Error[0].Exception.Message
        }
        elseif ($response -match "(good|nochg) (\d+\.\d+\.\d+\.\d+)") {
            # success
            trace "Success: $response"
            $recordstatus.result = 'success'
            $recordstatus.lastUpdate = [ordered]@{
                ip       = $Matches[2]
                response = $Matches[1]
                time     = $recordstatus.timestamp
            }
        }
        else {
            # error
            trace "Error: $response"
            $recordstatus.result = 'error'
            $recordstatus.error = $response
        }

        # Update status file
        $status[$record.hostname] = $recordstatus
        $status | ConvertTo-Json | Out-File -FilePath $config.statusPath
    }
    catch {
        $ex = $_ | Select-Object -ExpandProperty Exception | Out-String
        $ex += $_ | Select-Object -ExcludeProperty Exception | Out-String
        trace "Unexpected exception: $ex"
    }
}