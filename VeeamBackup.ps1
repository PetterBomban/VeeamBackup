<#
.Synopsis
    Uses Veeams Powershell api to back up servers.
.DESCRIPTION
    Uses Veeams Powershell api to back up servers.
    The script can handle a list of individual servers, like:
        "Webserver", "WSUS", "AD"
    Or you can use tags like:
        "WIN", "LIN", "OTH"
.EXAMPLE
    Start-VeeamZip `
        -ServerTypes "WIN","WEB" `
        -Destination "F:\Veeam\" `
        -Compression 5 `
        -Autodelete Never
.EXAMPLE
    Start-VeeamZip `
        -ServerTypes "ADServer", "Webserver", "WSUS" `
        -Destination "F:\Veeam\" `
        -Compression 0 `
        -Autodelete In1Month `
        -DisableQuiesce
#>
Function Start-VeeamZip()
{
    param
    (
        [Parameter(Mandatory=$True)][string[]]$ServerTypes = $(),
        [Parameter(Mandatory=$True)][string]$Destination,
        [Parameter(Mandatory=$True)][ValidateSet(0,4,5,6,9)][int]$Compression,
        [Parameter(Mandatory=$true)][ValidateSet(
            "Never",
            "Tonight",
            "TomorrowNight",
            "In3days",
            "In1Week",
            "In2Weeks",
            "In1Month"
        )][string]$Autodelete, #Doesn't work?
        [switch]$DisableQuiesce
    )

    ## Adds the Veeam Powershell module
    try
    {
        Add-PSSnapin VeeamPSSnapin
    }
    catch
    {
        Write-Output "Could not add Veeam Snapin. Exiting."
        return
    }

    ## If the destination is invalid, cancel the script
    if (!( Test-Path $Destination ))
    {
        Write-Output "$Destination -- Is an invalid destination. Exiting"
        exit
    }

    ## Get date in a format like this: 18.03.2016
    $DateT = Get-Date -Format d
    ## Days to keep backups for
    $KeepBackupsFor = 4 #days

    <#
        Checks for older backups and deletes them.
        Compares the date of a backup to the current date.
        If the difference is greater than $KeepBackupsFor, it deletes the folder.
    #>
    Get-ChildItem -Path $Destination | ForEach-Object {

        $ItemDate = $_.Name
        $Timespan = New-TimeSpan -Start $ItemDate -End $DateT
        Write-Output $ItemDate
        Write-Output "$($Timespan.TotalDays) - $ItemDate"
        if ( $($Timespan.TotalDays) -gt $KeepBackupsFor )
        {
            Write-Output "This is an old backup, deleting.."
            Remove-Item -Path "$Destination\$ItemDate" -Recurse
        }
    }

    Write-Output "STARTING BACKUP..."
    
    ## Foreach Servertype (or individual server)
    foreach ( $ServerType in $ServerTypes )
    {
        ## Find the servers in Veeam
        $VMEntity = Find-VBRViEntity | Where-Object { $_.Name -like "*$ServerType*" }

        ## foreach server that is found above
        foreach ( $VM in $VMEntity )
        {
            Write-Output "Backing up:"
            $VMName = $VM.Name

            ## We don't backup Logos (As we already have a backup of this script..)
            if ( $VMName -eq "WIN - Logos" -or $VMName -like "*Apoc*" )
            {
                Write-Output "Detected $VMName. This is flagged as do not backup, skipping.."
                continue
            }
            ## If the server is not found, go to next server in loop
            if ( $VM -eq $null )
            {
                Write-Output "$VM -- Not found"
                continue  
            }
            ## If the destination is invalid, cancel the script
            if (!( Test-Path $Destination ))
            {
                Write-Output "$Destination -- Is an invalid destination. Exiting"
                exit
            }

            ## TODO: Logs

            ## Creates a new path for the backups
            $BackupPath = "$Destination\$DateT\$VMName"
            New-Item -ItemType Directory -Path $BackupPath
            
            <#
                Runs the Veeam backup. 
                Disabling quiesce is not recommended, however quiesce will pause the server temporarily
            #>
            if ( $DisableQuiesce )
            {
                Start-VBRZip `
                    -Entity $VM `
                    -Folder $BackupPath `
                    -Compression $Compression `
                    -AutoDelete $Autodelete `
                    -RunAsync `
                    -DisableQuiesce
            }
            else
            {
                Start-VBRZip `
                    -Entity $VM `
                    -Folder $BackupPath `
                    -Compression $Compression `
                    -AutoDelete $Autodelete `
                    -RunAsync
            }

        }
        
    }
    
}

Start-VeeamZip -ServerTypes "WIN", "LIN", "WEB", "OTH" -Destination "E:\Veeam" -Compression 6 -Autodelete Never -DisableQuiesce
