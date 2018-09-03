[CmdletBinding()]
param(
    [string]$Hostname = 'home.dingletech.com',
    [string]$Username,
    [securestring]$Password, # ConvertTo-SecureString 'foo' -AsPlainText -Force
    [int]$UpdatePeriodInMin = 10, #minutes
    [int]$ForceUpdatePeriodInDays = 10 #days
)

$credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)

function trace($message) {
    Write-Output ((Get-Date).ToString('u') + ': ' + $message)
}

$lastip = 'unk'
$forceUpdate = (Get-Date).AddDays($ForceUpdatePeriodInDays)
while ($true) {

    $sleepMinutes = $UpdatePeriodInMin
    try {
        trace 'Fetching IP...'
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -ea Stop
        trace "IP: $ip"

        if ($ip -ne $lastip -OR (Get-Date) -ge $forceUpdate) {

            $url = "https://domains.google.com/nic/update?hostname=$Hostname&myip=$ip"
            trace "Updating DNS: $url"
            $res = Invoke-RestMethod $url -Credential $credential -ea Stop
            trace "Result: $res"
    
            if ($res -match "(good|nochg) (\d+\.\d+\.\d+\.\d+)") {
                trace 'Success.'
                $lastip = $Matches[2]
                $forceUpdate = (Get-Date).AddDays($ForceUpdatePeriodInDays)
            }
            elseif ($res -eq '911') {
                trace 'Error on Google''s end. Waiting 5 minutes.'
                $sleepMinutes = 5
            }
            else {
                Write-Error "We're doing something wrong! Quiting."
                return
            }
        } else {
            trace 'No change in IP.'
        }
    }
    catch {
        $_ | Write-Error
        $sleepMinutes = 1
    }

    trace "Sleeping for $sleepMinutes minutes..."
    Start-Sleep -Seconds ($sleepMinutes * 60)
}
