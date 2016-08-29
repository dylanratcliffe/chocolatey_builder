Param (
    [System.IO.DirectoryInfo]$Path,
    [Int32]$WatchIntervalSeconds = 10,
    [System.IO.DirectoryInfo]$OutputDir,
    [System.IO.DirectoryInfo]$ScriptPath = (Join-Path $pwd '.\Build-Package.ps1')
)

$folderSizes = @{}

while ($true) {

    # Get all of the grandchildren of the watch path (Builds)
    $buildFolders = (Get-Childitem (Get-ChildItem (Get-ChildItem -Path $Path).FullName).FullName)
    $currentTime = Get-Date

    # Loop over the build folders and check for changes
    ForEach ($buildFolder in $buildFolders) {
        # If it was modified in the second last interval then build that!
        if (!(Test-Path (Join-Path $buildFolder.FullName.ToString() '\Build Results.txt'))) {
            $folderLength = ((Get-Childitem $buildFolder.FullName -Recurse | Measure-Object -Property length -Sum).sum)
            if (($folderLength -eq $folderSizes[$buildFolder.FullName.ToString()])) {
                $scriptArgs = @(
                    '-Path',
                    $buildFolder.FullName.ToString(),
                    '-OutputDir',
                    $OutputDir.FullName.ToString()
                )
                Start-Job -Name ("Build " + $buildfolder.FullName) -FilePath $ScriptPath.FullName -ArgumentList $buildFolder.FullName.ToString(),$OutputDir.FullName.ToString()
            }
        }
        $folderSizes.Set_Item($buildFolder.FullName.ToString(),$folderLength)
    }

    sleep $WatchIntervalSeconds
}
