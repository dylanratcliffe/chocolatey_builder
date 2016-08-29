$ErrorActionPreference = 'Stop'; # stop on all errors

[[AutomaticPackageNotesInstaller]]
$packageName       = '[[PackageName]]'
$toolsDir          = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$websiteDir        = Join-Path (Split-Path -Parent $toolsDir) '\website'
$zipName           = ([System.IO.DirectoryInfo]"[[zipfile]]").Name
$websiteZip        = Join-Path $websiteDir $zipName
$packageParameters = $env:chocolateyPackageParameters
$matchPattern      = "installdir=(?<installdir>.*)"

# Try to get the Puppet environment, if Puppet isn't installed, return false
Try {
    $puppetEnvironment = (&"puppet" @("agent", "--configprint", "environment") | Out-String).Trim()
} Catch {
    $puppetEnvironment = $false
}

# Allow someone to pass in a parameter in the following format:
#   --package-parameters='installdir=C:\something\here'
# And have it override the default location
if ($packageParameters -match $matchPattern) {
	$installDir = $matches['installdir'].trim("'`"")
} else {
	$installDir = "C:\inetpub\[[PackageName]]"
}

# Try to remove the destination first, as we want a clean install
Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue

# Unzip the files into to destination
Get-ChocolateyUnzip `
  -FileFullPath $websiteZip `
  -Destination $installDir `
  -PackageName [[PackageName]]

# Only if we could get the environment should we bother trying to rename files
if ($puppetEnvironment) {
  # Get all of the files that need renaming
  $confinedFiles = (Get-ChildItem -Path $installDir -Filter '*.confine.*' -Recurse)
  if ($confinedFiles -ne $null) {
    ForEach ($file in $confinedFiles) {
      if ($file.Name -match "(?<basefilename>.*)\.confine\.${puppetEnvironment}") {
        Write-Host ("Renaming " + $file.Name + " to " + $matches['basefilename'])
        $file | Rename-Item -NewName $matches['basefilename']
      } else {
        Write-Host ("Deleting " + $file.Name)
        $file | Remove-Item -Force -Recurse
      }
    }
  }
}