[CmdletBinding()]
param(
    [string]$Hostname,
    [string]$Username,
    [securestring]$Password, # ConvertTo-SecureString '...' -AsPlainText -Force
    [string]$EmailUsername,
    [securestring]$EmailPassword,
    [int]$UpdatePeriodInMin = 10, #minutes
    [int]$ForceUpdatePeriodInDays = 10 #days
)

# Scheduled task command:
# PowerShell.exe -WindowStyle Hidden -ExecutionPolicy ByPass -NoProfile -NoLogo -Noninteractive -Command &{ Start-Transcript -Path 'C:\dev\ddns\log.txt' -Append; C:\dev\ddns\ddns.ps1 -Hostname 'example.com' -Username 'joe' -Password (ConvertTo-SecureString '...' -AsPlainText -Force) -EmailUsername 'joe@gmail.com' -EmailPassword (ConvertTo-SecureString '...' -AsPlainText -Force) -Verbose; Stop-Transcript }

function trace($message) {
    Write-Output ([datetime]::Now.ToString('u') + ': ' + $message)
}

try {
    if (!$Hostname) { throw 'Must supply hostname.' }
    if (!$Username) { throw 'Must supply user name.' }
    if (!$Password) { throw 'Must supply password.' }
    $credential = [pscredential]::new($Username, $Password)

    if ($EmailUsername)  {
        $emailCredential = [pscredential]::new($EmailUsername, $EmailPassword)
    }
    $script:noEmailUntil = [datetime]::Now.AddMinutes(5)
    function sendEmail($Subject, $Body) {
        if ($EmailUsername -and [datetime]::Now -ge $noEmailUntil)  {
            trace "Sending email to $EmailUsername : '$Subject' : $Body"
            Send-MailMessage -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl -Credential $emailCredential -to $EmailUsername -From $EmailUsername -Subject $Subject -Body $Body -ea Continue
            $script:noEmailUntil = [datetime]::Now.AddMinutes(30)
        }
    }
    
    $lastip = 'unk'
    $sleepMinutes = 0
    $forceUpdate = [datetime]::Now.AddDays($ForceUpdatePeriodInDays)
    while ($true) {

        if ($sleepMinutes -gt 0) {
            trace "Sleeping for $sleepMinutes minutes..."
            Start-Sleep -Seconds ($sleepMinutes * 60)
        }

        try {
            trace 'Fetching IP...'
            $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -ea Stop
            trace "IP: $ip"
        }
        catch {
            $_ | Write-Error
            sendEMail -Subject 'DDNS Error: Failed to query IP' -Body "$url returned: $res"
            $sleepMinutes = 5
            continue
        }

        if ($ip -eq $lastip) {
            trace 'No change in IP.'
            if ([datetime]::Now -lt $forceUpdate) {
                $sleepMinutes = $UpdatePeriodInMin
                continue
            }
        }

        $url = "https://domains.google.com/nic/update?hostname=${Hostname}&myip=${ip}"
        try {
            trace "Updating DNS: $url"
            $res = Invoke-RestMethod $url -Credential $credential -ea Stop
            trace "Result: $res"
        }
        catch {
            $_ | Write-Error
            sendEMail -Subject 'DDNS Error: Update DNS failed' -Body "Invoke-RestMethod '$url' failed:`n$_"
            $sleepMinutes = 5
            continue
        }

        if ($res -match "(good|nochg) (\d+\.\d+\.\d+\.\d+)") {
            trace 'Success.'
            $lastip = $Matches[2]
            $sleepMinutes = $UpdatePeriodInMin
            $forceUpdate = [datetime]::Now.AddDays($ForceUpdatePeriodInDays)
        }
        elseif ($res -eq '911') {
            trace 'Error on Google''s end.'
            $sleepMinutes = 5
        }
        else {
            sendEMail -Subject 'DDNS Error: Failed to update DNS' -Body "$url says '$res'"
            # We are likely doing something wrong.
            # Sleep long time to avoid getting in trouble with Google
            $sleepMinutes = 120
        }
    }
}
catch {
    if ($ErrorActionPreference -eq 'Stop') {
        throw
    }
    if ($ErrorActionPreference -ne 'Ignore') {
        $_ | Write-Error
    }
}
