# DDNS Registration Client for Cloudflare DNS

A powershell script to update [Cloudflare DNS](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-patch-dns-record) records in [cloudflare](https://www.cloudflare.com/products/registrar/).

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
