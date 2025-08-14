[cmdletbinding()]
param(
 [Parameter(Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [string]$SISServer,
 [Parameter(Mandatory = $true)]
 [string]$SISDatabase,
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$SISCredential,
 # [Parameter(Mandatory = $False)]
 # [string]$StaffGroup,
 [Parameter(Mandatory = $True)]
 [string]$StudentGroup,
 [Parameter(Mandatory = $True)]
 [string]$TeacherCoursesJSON,
 [switch]$ClearGroup,
 [Alias('wi')]
 [switch]$WhatIf
)


function Get-ADStudent {
 process {
  if (!$_) { return }
  $filter = 'employeeId -eq {0}' -f $_
  Get-ADUser -Filter $filter
 }
}

function Add-GroupMembers ($group) {
 begin { $members = @() }
 process {
  if ($_) {
   Write-Host ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $group, $_.SamAccountName) -F Green
   $members += $_.ObjectGUID.Guid
  }
 }
 end {
  Add-ADGroupMember -Identity $group -Members $members -Confirm:$false -WhatIf:$WhatIf
  $grpObj = Get-ADGroupMember -Identity $StudentGroup
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $StudentGroup, @($grpObj).count) -F Green
 }
}

function Remove-GroupMembers {
 Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $StudentGroup) -F Magenta
 $memberSams = (Get-ADGroupMember -Identity $StudentGroup | Select-Object -Property SamAccountName).SamAccountName
 if ($null -eq $memberSams) { return }
 Remove-ADGroupMember -Identity $StudentGroup -Members $memberSams -Confirm:$false -WhatIf:$WhatIf
}

function Get-jsonData ($obj) {
 $propNames = ($obj.teachers | Get-Member -MemberType NoteProperty | Select-Object Name).name
 foreach ($name in $propNames) {
  $obj.teachers.$name
 }
}

function Get-PermIdsFromJson ($params) {
 begin {
  $regularScheduleSql = Get-Content -Raw -Path '.\sql\RegularSchedule.sql'
  $blockScheduleSql = Get-Content -Raw -Path '.\sql\BlockSchedule.sql'
 }
 process {
  $baseSql = if ($_.type -eq "regular") { $regularScheduleSql } elseif ($_.type -eq "block") { $blockScheduleSql }
  $myValues = '(' + ($_.course -join '),(') + ')'
  $sql = $baseSql -replace ('MY_VALUES', $myValues)

  Write-Host ('{0},[{1}],[{2}],[{3}],[{4}]' -f $MyInvocation.MyCommand.Name, $_.id, $_.name, $_.type, ($_.course -join ',')) -F DarkGreen

  $ids = New-SqlOperation @params -Query $sql -Parameters ("id=$($_.id)")
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $_.name, @($ids).count) -F Blue
  $ids.ID
 }
}
# ============================================================================================

Import-Module -Name CommonScriptFunctions, dbatools

Show-BlockInfo start
if ($WhatIf) { Show-TestRun }

Clear-SessionData
$adCmdLets = 'Add-ADPrincipalGroupMembership', 'Get-ADGroupMember', 'Get-ADUser', 'Remove-ADGroupMember'
Connect-ADSession -DomainControllers $DomainControllers -Cmdlets $adCmdLets -Credential $ADCredential

$sisParams = @{
 Server     = $SISServer
 Database   = $SISDatabase
 Credential = $SISCredential
}

if ($ClearGroup) { Remove-GroupMembers }
$jsonData = Get-jsonData (Get-Content -Path $TeacherCoursesJSON -Raw | ConvertFrom-Json)
$jsonData | Get-PermIdsFromJson $sisParams | Get-ADStudent | Add-GroupMembers $StudentGroup

if ($WhatIf) { Show-TestRun }
Show-BlockInfo end