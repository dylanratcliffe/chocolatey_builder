Param(
 [System.IO.DirectoryInfo]$Path,
 [System.IO.DirectoryInfo]$OutputDir = '.\',
 [String]$Template = 'iis_site'
)

# Custom function for logging to both stdout and a file
function Write-Log {
    Param($message = $false)
    # Allow input to be piped in if no params
    if ($message -eq $false) {
        ForEach ($i in $input) {
            Write-Host $i
            $i | Out-File -FilePath (Join-Path $script:Path '\Build Results.txt') -Append
        }
    } else {
        # If we are not piping input in then just do the plain old print
        Write-Host $message
        $message | Out-File -FilePath (Join-Path $script:Path '\Build Results.txt') -Append
    }
}

$7zExe          = Join-Path $env:ChocolateyInstall '\tools\7z.exe' 
$packageName    = $Path.Parent.Name.ToLower()
$packageVersion = $Path.Name
$tempFile       = Join-Path ([System.IO.Path]::GetTempPath()) ($packageName + '.' + $packageVersion + ".7z")
$tempCache      = New-Item (Join-Path ([System.IO.Path]::GetTempPath()) ($packageName + '.' + $packageVersion)) -type directory
$outPackage     = [System.IO.DirectoryInfo](Join-Path (Join-Path $tempCache $packageName) ($packageName + '.' + $packageVersion + ".nupkg"))

Write-Log "------- Build Details -------"
Write-Log "Using 7zip from here: $7zExe"
Write-Log "Package Name: $packageName"
Write-Log "Package Version: $packageVersion"
Write-Log "-----------------------------"
Write-Log ""
Write-Log "Compressing site to .7z archive..."

$7zArgs = @(
    'a',
    '-t7z',
    '-r',
    $tempFile,
    ($Path.ToString() + "\*")
)

# Zip up the website
&$7zExe $7zArgs 2>&1 | Write-Log

Write-Log ""
Write-Log "Building .nuspec file and installer..."
Write-Log ""

$chocoArgs = @(
    'new'
    $packageName,
    '--a',
    '--version',
    $packageVersion,
    '--template',
    $Template,
    '--outputdirectory',
    $tempCache,
    "zipfile=$tempFile",
    '--force'
)

# Use a template to generate the skeleton of the chocolatey package
&'choco' $chocoArgs 2>&1 | Write-Log

Write-Log ""
Write-Log "Packing files into Chocolatey Package"
Write-Log ""

$chocoPackArgs = @(
    'pack',
    '--cache',
    $tempCache.FullName
)

# Pack the chocolay package
Push-Location (Join-Path $tempCache $packageName)
$r = &'choco' 'pack' 2>&1 | Write-Log
Pop-Location

Write-Log ""
Write-Log "Removing temporary files..."
Write-Log ""

# Remove the .7z archive
Remove-Item $tempFile
# Move the nupkg file up to the OutputDir
Copy-Item (Get-Item $outPackage) $OutputDir -Force
# Remove the folder with the .nuspec file that got created at build time
Remove-Item (Join-Path $tempCache $packageName) -Recurse
Remove-Item $tempCache -Recurse -Force

Write-Log "Done."
Write-Log ""
Write-Log "Install the package with the following Puppet code:"
Write-Log ""
Write-Log "package { '$packageName' :"
Write-Log "  ensure          => '$packageVersion',"
Write-Log "  install_options => `"--package-parameters='installdir=C:\\some\\location'`","
Write-Log "  provider        => 'chocolatey',"
Write-Log "}"