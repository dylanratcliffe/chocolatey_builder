$ErrorActionPreference = 'Stop'; # stop on all errors

# Grab all of the info about the current package
$packageFolder  = $env:chocolateyPackageFolder
$packageName    = $env:chocolateyPackageName
$packageVersion = $env:chocolateyPackageVersion
$logFile        = (Join-Path $packageFolder ($packageName + '.' + $packageVersion + '.7z.txt'))

# Read in the log file that was written when it extracted the initial 7z
Write-Host "Reading $logFile"
$logFileContent = Get-Content $logFile

# Strip any empty lines
$logFileContent = $logFileContent | ? {$_}

# Reverse the array so that we delete in the opposite order the files were created
[array]::Reverse($logFileContent)

# Delete everything that 7z created
ForEach ($file in $logFileContent) {
	Remove-Item $file -Recurse -Force
}