# DDNS Registration Client for Google Domains

A powershell script to update [dynamic DNS](https://support.google.com/domains/answer/6147083) records in [Google Domains](https://domains.google.com/).

## Usage

Create a config file at `~/.ddns/config.json` and add your records to it. See [config.json](.\config.json) for an example.

Run the script to update the DDNS records:

```powershell
C:\dev\ddns\update-ddns.ps1
```

## Run on a schedule

The following powershell script will create a Scheduled Task which starts at logon of the current user and then runs daily at 8AM:

```powershell
cd ~\Dev\Update-IPFilter

New-ScheduledTask `
    -Action (New-ScheduledTaskAction `
        -Execute (Get-Command pwsh).Path `
        -Argument '-nologo -nop -ep bypass -w hidden -f update-ddns.ps1' `
        -WorkingDirectory $PWD) `
    -Trigger `
        (New-ScheduledTaskTrigger -AtLogOn),
        (New-ScheduledTaskTrigger -Daily -At (Get-Date '08:00')) | `
Register-ScheduledTask -TaskName 'Update DDNS' -Force

# Execute now:
Start-ScheduledTask -TaskName 'Update DDNS'

# Delete:
# Unregister-ScheduledTask -TaskName 'Update DDNS'
```
