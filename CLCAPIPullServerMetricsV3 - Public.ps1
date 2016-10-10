<#

Script to pull a server utilization report for Virtual Machines in CenturyLink Cloud

Author: Matt Schwabenbauer
Created: March 30, 2016
E-mail: Matt.Schwabenbauer@ctl.io

Step 1 -
In order to enable scripts on your machine, first run the following command:
Set-ExecutionPolicy RemoteSigned

Step 2 - Press F5 to run the script

Step 3 - Enter your API Key 
    This can be found on the API section in Control
    If your name is not listed among the API users, create a ticket requesting access

Step 4 - Enter your API password

Step 5 - Enter your control portal account login information

Step 6 - Enter Customer account alias

Step 7 - The Output file will be in C:\users\Public\CLC\

#>

Write-Verbose "This script will output the past 24 hours of CenturyLink Cloud server metrics and utilization data for a given account alias." -verbose
Write-Verbose "It will also identify any machines that had an average CPU, RAM or HD utilization above 70% or under 25% during that time frame." -verbose
Write-Verbose "A report containing metrics for each server will be opened at the end of the operation. The reports containing high/low resource utilization data will be stored at C:\Users\Public\CLC." -verbose

# Get the parent account alias from the user

$AccountAlias = Read-Host "Please enter a parent account alias"

#generate very specific date and time for filename
$genday = Get-Date -Uformat %a
$genmonth = Get-Date -Uformat %b
$genyear = Get-Date -Uformat %Y
$genhour = Get-Date -UFormat %H
$genmins = Get-Date -Uformat %M
$gensecs = Get-Date -Uformat %S

$gendate = "Generated-$genday-$genmonth-$genyear-$genhour-$genmins-$gensecs"

<# Create Directory #>

$dir = "C:\users\Public\CLC\$AccountAlias\ServerMetricReports\$gendate\"

Write-Verbose "Creating the directory $dir. Note: a number of temp files will be created in this location and then deleted at the end of the operation." -Verbose
Write-Verbose "Reports identifying Virtual Machines with high or low resource utilization will be located in $dir at the end of the operation. There will also be a report with utilization metrics over the same time period for all Virtual Machines in $accountalias." -Verbose

New-Item -ItemType Directory -Force -Path $dir

<# API V1 Login #>

Write-Verbose "Logging in to CLC API V1." -verbose

$APIKey = Read-Host "Please enter your CLC API V1 API Key"
$APIPass = Read-Host "Please enter your CLC API V1 API Password"

$body = @{APIKey = $APIKey; Password = $APIPass } | ConvertTo-Json
$restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logon/" -ContentType "Application/JSON" -Body $body -Method Post -SessionVariable session 
$global:session = $session 
Write-Host $restreply.Message

if ($restreply.StatusCode -eq 100)
{
   Write-Verbose "Error logging in to CLC API V1." -Verbose
   exit 1
}
Else
{
}

<# API V2 Login: Creates $HeaderValue for Passing Auth (highlight and press F8) #>

Write-Verbose "Logging in to CLC API V2." -verbose

try
{
$global:CLCV2cred = Get-Credential -message "Please enter your Control portal Logon" -ErrorAction Stop 
$body = @{username = $CLCV2cred.UserName; password = $CLCV2cred.GetNetworkCredential().password} | ConvertTo-Json 
$global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $body -Method Post 
$HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken} 
}
catch
{
    Write-Verbose "Error logging in to CenturyLink Cloud v2 API." -Verbose
    exit 2
}


$DCURL = "https://api.ctl.io/v2/datacenters/$AccountAlias"
$datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
$datacenterList = $datacenterList.id

$result = $null
$groups = $null
$aliases = $null
$serverNames = $null
$errorgroups = @()

<# generate date for temp file names #>
$date = Get-Date -Format Y

<# generate file names for temp files #>
$groupfilename = "$dir\$AccountAlias-AllGroups-$date.csv"
$aliasfilename = "$dir\$AccountAlias-AllAliases-$date.csv"

function getServers
{
    $Location = $args[0]
    $JSON = @{AccountAlias = $AccountAlias; Location = $Location} | ConvertTo-Json 
    $result = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON 
    $result.AccountServers.Servers | Export-Csv "$dir\RawData.csv" -Append -ErrorAction SilentlyContinue -NoTypeInformation
    $result.AccountServers | Export-Csv "$dir\rawdata2.csv" -Append -ErrorAction SilentlyContinue -NoTypeInformation
    }

Foreach ($i in $datacenterList)
{
    getServers($i)
}

Import-Csv "$dir\RawData.csv" | Select HardwareGroupUUID -Unique  | Export-Csv $groupfilename  -NoTypeInformation
Import-Csv "$dir\rawdata2.csv" | Select AccountAlias -Unique  | Export-Csv $aliasfilename  -NoTypeInformation

$groups = Import-csv $groupfilename
$aliases = Import-csv $aliasfilename

$allRows = @()

$start = ((get-date).addDays(-1).ToUniversalTime()).ToString("yyyy-MM-dd")+"T00:00:01.000z"
$end = ((get-date).addDays(-1).ToUniversalTime()).ToString("yyyy-MM-dd")+"T23:59:59.000Z"

Foreach ($alias in $aliases)
{
    $writeAlias = $alias.AccountAlias
    Write-Verbose "Gathering data for subaccount $writeAlias." -verbose
    $result = $null
Foreach ($group in $groups)
{
    $result = $null
    $thisgroup = $group.HardwareGroupUUID
    $thisalias = $alias.AccountAlias
    $url = "https://api.ctl.io/v2/groups/$thisalias/$thisgroup/statistics?type=hourly&start=$start&end=$end&sampleInterval=23:59:58"
    try
    {
     $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
    }
    catch
    {
    }
    if ($result)
    {

  Foreach ($i in $result)
  {
    $totalstorageusage = $null
    Foreach ($j in $i.stats.guestDiskUsage)
    {

    $StorageUsage = [int]$j.consumedMB
    $totalstorageusage += $storageusage
    }
   
   # $allrows | Add-Member @{ "Server Name" = $i.name; "Time" = $i.stats.timestamp; "CPU Amount" = $i.stats.cpu; "CPU Utilization" = $i.stats.cpuPercent; "Total RAM" = $i.stats.memoryMB; "RAM Utilization" = $i.stats.memoryPercent; "Total Storage" = $i.stats.diskUsageTotalCapacityMB}
  $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value $i.name 
                $thisrow | Add-Member -MemberType NoteProperty -Name "Date & Time" -Value $i.stats.timestamp[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "CPUAmount" -Value $i.stats.cpu[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "CPUUtil" -Value $i.stats.cpuPercent[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "MemoryMB" -Value $i.stats.memoryMB[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "MemoryUtil" -Value $i.stats.memoryPercent[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "Storage" -Value $i.stats.diskUsageTotalCapacityMB[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "networkReceivedKbps" -Value $i.stats.networkReceivedKbps[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "networkTransmittedKbps" -Value $i.stats.networkTransmittedKbps[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "predictedTransmittedMB" -Value (($i.stats.networkTransmittedKbps[0] * 0.0001220703125) * 86400)
                $thisrow | Add-Member -MemberType NoteProperty -Name "predictedReceivedMB" -Value (($i.stats.networkReceivedKbps[0] * 0.0001220703125) * 86400)
  if ($totalstorageusage -eq $null)
  {
    $thisrow | Add-Member -MemberType NoteProperty -Name "Storage Usage" -Value "0"
  }
  else
  {
    $thisrow | Add-Member -MemberType NoteProperty -Name "Storage Usage" -Value $totalstorageusage
  }
  $storageutilization = (($totalstorageusage)/[int]$i.stats.diskUsageTotalCapacityMB[0])*100
  $storageutilization = "{0:N0}" -f $storageutilization
  $thisrow | Add-Member -MemberType NoteProperty -Name "Storage Utilization %" -Value $storageutilization
  $allrows += $thisrow
  } # end foreach result
    } # end if result
    else
    { 
    }
} # end foreach group
} # end foreach alias

$filename = "$dir\$accountAlias-ServerMetrics-$gendate.csv"

# Filter high utilization servers

Write-Verbose "Calculating servers with high resource utilization." -Verbose

$highCPUUtil = @()
$highRAMUtil = @()
$highHDUtil = @()
$lowCPUUtil = @()
$lowRAMUtil = @()
$lowHDUtil = @()

$highCPUUtil += $allrows | Select-Object | Where-Object {[int]$_.CPUUtil -gt 70}
$highRAMUtil += $allrows | Select-Object | Where-Object {[int]$_.MemoryUtil -gt 70}
$highHDUtil += $allors | Select-Object | Where-Object {[int]$_.StorageUtil -gt 70}
$lowCPUUtil += $allrows | Select-Object | Where-Object {[int]$_.CPUUtil -lt 25}
$lowRAMUtil += $allrows | Select-Object | Where-Object {[int]$_.MemoryUtil -lt 25}
$lowHDUtil += $allors | Select-Object | Where-Object {[int]$_.StorageUtil -lt 25}

# Check to see if there aren't any servers with high/ow utilization, and give the user some direction if so

if (!$highCPUUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with CPU utilization over 70%"
    $highCPUUtil = $thisrow
  }

  if (!$highRAMUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with RAM utilization over 70%"
    $highRAMUtil = $thisrow
  }

  if (!$highHDUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with storage utilization over 70%"
    $highHDUtil = $thisrow
  }

  if (!$lowCPUUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with CPU utilization under 25%"
    $lowCPUUtil = $thisrow
  }

  if (!$lowRAMUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with RAM utilization under 25%"
    $lowRAMUtil = $thisrow
  }

  if (!$lowHDUtil)
  {
    $thisrow = New-object system.object
    $thisrow | Add-Member -MemberType NoteProperty -Name "No Data" -Value "No servers were identified with storage utilization under 25%"
    $lowHDUtil = $thisrow
  }

# Export data

Write-Verbose "Exporting all server utilization data." -Verbose

$allrows | export-csv $filename -NoTypeInformation

Write-Verbose "Exporting High CPU Utilization data for $AccountAlias." -Verbose

$highCPUUtil | export-csv "$dir\$AccountAlias-HighCPU-$gendate.csv" -NoTypeInformation

Write-Verbose "Exporting High RAM Utilization data for $AccountAlias." -Verbose

$highRAMUtil | export-csv "$dir\$AccountAlias-HighRAM-$gendate.csv" -NoTypeInformation

Write-Verbose "Exporting High HD Utilization data for $AccountAlias." -Verbose

$highHDUtil | export-csv "$dir\$AccountAlias-HighHD-$gendate.csv" -NoTypeInformation

Write-Verbose "Exporting low CPU Utilization data for $AccountAlias.csv" -Verbose

$lowCPUUtil | export-csv "$dir\$AccountAlias-LowCPU-$gendate.csv" -NoTypeInformation

Write-Verbose "Exporting low RAM Utilization data for $AccountAlias.csv" -Verbose

$lowRAMUtil | export-csv "$dir\$AccountAlias-LowRAM-$gendate.csv" -NoTypeInformation

Write-Verbose "Exporting low HD Utilization data for $AccountAlias." -Verbose

$lowHDUtil | export-csv "$dir\$AccountAlias-LowHD-$gendate.csv" -NoTypeInformation

# Open the files you just exported

Write-Verbose "Opening server metrics for $AccountAlias." -verbose

$file = & $filename

Write-Verbose "Logging out of the API." -verbose
 
$restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logout/" -ContentType "Application/JSON" -Method Post -SessionVariable session 
$global:session = $session
Write-Host $restreply.Message

Write-Verbose "Deleting Temp files." -verbose

Remove-Item "$dir\RawData.csv"
Remove-Item "$dir\RawData2.csv"
Remove-Item $groupfilename
Remove-Item $aliasfilename

Write-Verbose "Operation Complete." -verbose
Write-Verbose "Reports identifying Virtual Machines with high or low resource utilization will be located in $dir. There will also be a report with utilization metrics over the same time period for all Virtual Machines in $accountalias." -Verbose