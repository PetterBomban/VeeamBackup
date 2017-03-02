<#
.Synopsis
    Uses the Veeam Powershell module to back up servers.
.DESCRIPTION
    Uses the Veeam Powershell module to back up servers.
    The script can handle a list of individual servers, like:
        "Webserver", "WSUS", "AD"
    Or you can use tags like:
        "WIN", "LIN", "OTH"
.EXAMPLE
    $Params = @{
        ServerTypes = "WIN", "LIN", "WEB", "OTH", "BSD" ## Specify either tags or exact server names
        Skip = "WIN - Sentinel", "WIN - Apoc"           ## Need the exact name for skip to work
        Destination = "E:\Veeam"                        ## Backup-files output folder
        Compression = 6                                 ## 0,4,5,6,9
        KeepBackupsFor = 4                              ## Days. 0 = Forever
        DisableQuiesce = $True                          ## $True, $False
    }
    Start-VeeamZip @Params
#>
Function Start-VeeamZip()
{
    param
    (
        [Parameter(Mandatory=$True)]
        [string[]] $ServerTypes = @(),

        [Parameter(Mandatory=$False)]
        [string[]] $Skip = @(),

        [Parameter(Mandatory=$True)]
        [string] $Destination,

        [Parameter(Mandatory=$True)][ValidateSet(0,4,5,6,9)]
        [int] $Compression,

        [switch] $DisableQuiesce,
        [int] $KeepBackupsFor = 0
    )

    Add-PSSnapin VeeamPSSnapin -ErrorAction Stop

    ## If the destination is invalid, cancel the script
    if (!(Test-Path $Destination))
    {
        throw "$Destination -- is an invalid destination."
    }

    ## Get date in a format like this: 27.02.2017
    $DateT = Get-Date -Format d
    
    # Checks for older backups and deletes them.
    # Compares the date of a backup to the current date.
    # If the difference is greater than $KeepBackupsFor, it deletes the folder.
    # Skips if $KeepBackupsFor -eq 0 (Backups are kept forever)
    Get-ChildItem -Path $Destination | ForEach-Object {
        if ($KeepBackupsFor -eq 0) { return }
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
    foreach ($ServerType in $ServerTypes)
    {
        ## Find the servers in Veeam
        $VMEntity = Find-VBRViEntity | Where-Object { $_.Name -like "*$ServerType*" }

        ## foreach server that is found above
        foreach ($VM in $VMEntity)
        {
            $VMName = $VM.Name
            Write-Output "Backing up: $VMName"

            ## If the server is not found, go to next server in loop
            if ($VM -eq $null)
            {
                Write-Output "$VMName -- not found"
                continue  
            }

            ## Skip servers specified in the -Skip parameter
            $SkipServer = $False
            $Skip | ForEach-Object {
                if ($VMName -eq $_) 
                {
                    Write-Output "$_ -- skipping server."
                    $SkipServer = $True
                    return
                }
            }
            if ($SkipServer) { continue }

            ## Creates a new path for the backups
            $BackupPath = Join-Path -Path $Destination -ChildPath "$DateT/$VMName"
            New-Item -ItemType Directory -Path $BackupPath
            
            ## Runs the Veeam backup. 
            $Splat = @{
                Entity = $VM
                Folder = $BackupPath
                Compression = $Compression
                AutoDelete = "Never"
                RunAsync = $True
                DisableQuiesce = $DisableQuiesce
            }
            Start-VBRZip @Splat -ErrorAction Stop
        }
    }
}

$Params = @{
    ServerTypes = "WIN", "LIN", "WEB", "OTH", "BSD"
    Skip = "WIN - Sentinel", "WIN - Apoc"
    Destination = "E:\Veeam"
    Compression = 6
    KeepBackupsFor = 4
    DisableQuiesce = $True
}
Start-VeeamZip @Params
