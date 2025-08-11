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
 begin { $objGUIDS = @() }
 process {
  if (!$_) { return }
  $filter = 'employeeId -eq {0}' -f $_
  $adObj = Get-ADUser -Filter $filter
  if ($adObj) {
   Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $adObj.SamAccountName) -F Green
   # Keep adding Guids for all teachers and courses until they are all in the array
   $objGUIDS += $adObj.ObjectGUID.Guid
  }
 }
 end { $objGUIDS }
}

function Add-GroupMembers ($group) {
 process {
  if ($user) {
   Write-Verbose ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $StudentGroup)
   Add-ADGroupMember -Identity $group -Members $_ -Confirm:$false -WhatIf:$WhatIf
  }
 }
 end {
  $grpObj = Get-ADGroupMember -Identity $StudentGroup
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $StudentGroup, @($grpObj).count) -F Green
 }
}

function Remove-GroupMembers {
 Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $StudentGroup)
 Get-ADGroupMember -Identity $StudentGroup |
  ForEach-Object {
   Remove-ADGroupMember -Identity $StudentGroup -Members $_.SamAccountName -Confirm:$false -WhatIf:$WhatIf
  }
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

  Write-Verbose ('{0},[{1}],[{2}],[{3}],[{4}]' -f $MyInvocation.MyCommand.Name, $_.id, $_.name, $_.type, ($_.course -join ','))

  $ids = New-SqlOperation @params -Query $sql -Parameters ("id=$($_.id)")
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $_.name, @($ids).count) -F Blue
  $ids.ID
 }
}
# ============================================================================================

Import-Module -Name CommonScriptFunctions, dbatools

Show-BlockInfo start
if ($WhatIf) { Show-TestRun }

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