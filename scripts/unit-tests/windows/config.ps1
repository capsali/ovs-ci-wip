# Environment variables
$ENV:PATH = "C:\Perl64\bin;$ENV:PATH"
$ENV:PATH += ";${ENV:ProgramFiles}\7-Zip"
$ENV:PATH += ";${ENV:ProgramFiles}\Git\bin"
$ENV:PATH += ";${ENV:ProgramFiles(x86)}\CMake\bin"
$ENV:PATH += ";C:\Python27"
$ENV:PATH += ";C:\Python3"
$ENV:PATH += ";${ENV:ProgramFiles(x86)}\PuTTY"
$ENV:PATH = "C:\mingw\msys\1.0\bin;$ENV:PATH"

# Jenkins Job Variables
$commitID = $env:commitid
$Status = $env:status
$workspace = $env:WORKSPACE

# OVS git URL
$OVS_URL = "https://github.com/openvswitch/ovs.git"

# Path variables
$basePath = "C:\OpenStack\OpenvSwitch"
$buildDir = "$basePath\Build"
$commitDir = "$buildDir\$commitID"
$outputPath = "$commitDir\bin"
$outputSymbolsPath = "$commitDir\symbols"
#Git clone Dir
$gitcloneDir = "$commitDir\ovs"
$commitmsiDir = "$basePath\installer\$commitID"
$localLogs = "$basePath\logs"
$commitlogDir = "$localLogs\$commitID"
#automake already appends \lib\<platform> to the pthread library
$winPthreadLibDir = "$basePath\pthread"
$pthreadDir = $winPthreadLibDir.Replace("\", "/")
# Visual Studio version
$vsVersion = "12.0"
$platform = "x86_amd64"

# Remote Log Server Variables
$remoteServer = "10.20.1.14"
$remoteUser = "logs"
$remoteKey = "C:\ovs-ci\scripts\unit-tests\ssh\norman.ppk"
$remotelogDir = "/srv/logs/ovs"
$remotemsiDir = "/srv/dl/ovs" 
$remotelogdirPath = "$remotelogDir/$commitID"
$remotemsidirPath = "$remotemsiDir/$commitID"

# Email Job Variables
#$smtpServer = "192.168.1.3"
$smtpServer = "mail.cloudbasesolutions.com"
$from = "microsoft_ovs_ci@microsoft.com"
$to = "mgheorghe@cloudbasesolutions.com"
$commitLink = "https://github.com/openvswitch/ovs/commit/$commitID"
$privatelogLink = "http://$remoteServer/ovs/$commitID"
$publiclogLink = "http://64.119.130.115/ovs/$commitID"
