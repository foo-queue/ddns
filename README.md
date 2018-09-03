# DDNS Script for Google Domains
A powershell script to update a [Syntheic Dynamic DNS](https://support.google.com/domains/answer/6147083) record in Google Domains. 

### Usage:
```powershell
.\ddns.ps1 -Hostname <your.google.domain> -Username <username> -Password (ConvertTo-SecureString <password> -AsPlainText -Force) -Verbose }
```
