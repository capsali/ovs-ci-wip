# Source the config and utils scripts.
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\config.ps1"
. "$scriptPath\utils.ps1"


$messageUri = "$privatelogLink/commitmessage.txt.gz"
$messageOutFile = "$localLogs\message-$commitID.txt"
ExecRetry {
write-host "connecting to $messageUri"
Invoke-WebRequest -Uri $messageUri -OutFile $messageOutFile
}
$commitMessage = Get-Content $messageOutFile -Raw

if ( $Status -eq "UNITPASS" ) {
        write-host "Sending Unit Tests Pass E-mail for $commitID"
        Send-PassEmail $from $to $smtpServer $commitLink $publiclogLink
}

if ( $Status -eq "UNITFAIL" ) {
        write-host "Sending Unit Tests Fail E-mail for $commitID"
        Send-FailEmail $from $to $smtpServer $commitLink $publiclogLink
}

if ( $Status -eq "ERROR" ) {
        write-host "Sending make error E-mail for $commitID"
        Send-PassEmail $from "mgheorghe@cloudbasesolutions.com" $smtpServer $commitLink $publiclogLink
}

Remove-Item -Path $messageOutFile -Force