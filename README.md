# VeeamBackup

This script is used for automatic backups of vSphere VM's, using Veeam. You need to run this script on a server that has the Veeam management console (and PoSh module) installed. The script works perfectly with the free version of Veeam B&R.

## Usage

```PowerShell
Start-VeeamZip [-ServerTypes <string[]>] [-Skip <string[]>] [-Destination <string>]
                [-KeepBackupsFor <int>] [-Compression <int>] [-DisableQuiesce]  
```

### -ServerTypes *string[]*
We name our VM's with tags first (ex.: WIN - DomainController), so the script will look for the specified tags, but you can also specify exact names here. Wildcard (*) also supported.

### -Skip *string[]*
Exact name of server(s) to skip.

### -Destination *string*
Destination of the backup. If $Destination = "F:\Backup", then the individual servers will be stored under:
`"F:\Backup\27.02.2017\WIN - DomainController\"`

### -KeepBackupsFor *int*
This specifies number of days that old backups are kept for. 0 = Keep forever

### -Compression *int*
Valid numbers: 0,4,5,6,9

### -DisableQuiesce
If set, the VM will be backed up without using the VMware tools quiescence.

## Tested on
Windows Server 2012 R2 and Windows Server 2016 

## License
MIT License
