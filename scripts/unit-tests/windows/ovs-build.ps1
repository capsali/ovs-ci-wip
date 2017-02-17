Param(
)
$ErrorActionPreference = "Stop"

# Source the config and utils scripts.
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\config.ps1"
. "$scriptPath\utils.ps1"

CheckLocalPaths
# Create the log paths on the remote log server
CheckRemotePaths $remotelogdirPath

pushd $commitDir
GitClonePull $gitcloneDir $OVS_URL
popd
pushd $gitcloneDir
Set-GitCommidID $commitID
Set-commitInfo

$msysCwd = "/" + $pwd.path.Replace("\", "/").Replace(":", "")

# Make Visual Studio Paths available to msys.
Set-VCVars $vsVersion $platform
# This must be the Visual Studio version of link.exe, not MinGW
$vsLink = $(Get-Command link.exe).path
$vsLinkPath = $vsLink.Replace("\", "/").Replace(":", "")

$makeScriptPath = Set-MakeScript
Get-Content $makeScriptPath
write-host "Running make on OVS commit $commitid"
&bash.exe $makeScriptPath | Tee-Object -FilePath "$commitlogDir\makeoutput.log"
    if ($LastExitCode) {
        CompressLogs "$commitlogDir"
        Copy-RemoteLogs "$commitlogDir\*"
        New-Item -Type file -Force -Path "$workspace\params.txt" -Value "status=ERROR"
        #Start-MailJob "{jenkins_user}" "{jenkins_pass}" "ERROR"
        popd
        Cleanup
        throw "make.sh failed"
    }
    else {
        write-host "Finished compiling. Moving on..."
    }
    
$unitScriptPath = Set-UnitScript
Get-Content $unitScriptPath
write-host "Running unit tests!"
&bash.exe $unitScriptPath | Tee-Object -FilePath "$commitlogDir\unitsoutput.log"
    if ($LastExitCode) {
        Copy-LocalLogs
        CompressLogs "$commitlogDir"
        Copy-RemoteLogs "$commitlogDir\*"
        New-Item -Type file -Force -Path "$workspace\params.txt" -Value "status=UNITFAIL"
        #Start-MailJob "{jenkins_user}" "{jenkins_pass}" "UNITFAIL"
        popd
        Cleanup
        throw "Unit tests failed. The logs have been saved."
    }
    else {
        write-host "unit tests succeded. Moving on"
        Copy-LocalLogs
        CompressLogs "$commitlogDir"
        Copy-RemoteLogs "$commitlogDir\*"
        New-Item -Type file -Force -Path "$workspace\params.txt" -Value "status=UNITPASS"
        #Start-MailJob "{jenkins_user}" "{jenkins_pass}" "UNITPASS"
    }
    
$msiScriptPath = Set-MsiScript
Get-Content $msiScriptPath
write-host "Building OVS MSI."
&bash.exe $msiScriptPath | Tee-Object -FilePath "$commitlogDir\msioutput.log"
    if ($LastExitCode) { 
        cd $buildDir
        CompressLogs "$commitlogDir"
        Copy-RemoteLogs "$commitlogDir\msioutput.log.gz"
        popd
        Cleanup
        throw "Failed to create OVS msi." 
    }
    else { 
        write-host "OVS msi created."
        # Create the msi remote log paths
        CheckRemotePaths $remotemsidirPath
        CompressLogs "$commitlogDir"
        Copy-LocalMsi
        Copy-RemoteLogs "$commitlogDir\msioutput.log.gz"
        Copy-RemoteMSI "$gitcloneDir\windows\ovs-windows-installer\bin\Release\OpenvSwitch.msi"
		Copy-RemoteMSI "$gitcloneDir\datapath-windows\x64\Win8.1Debug\package.cer"
        popd
        Cleanup
    }
