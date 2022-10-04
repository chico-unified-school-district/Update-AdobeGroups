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

function Add-GroupMember {
 begin {
  Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $StudentGroup)
 }
 process {
  $filter = 'employeeId -eq {0}' -f $_.id
  $user = Get-ADUser -Filter $filter
  if ($user) {
   Write-Verbose ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $StudentGroup, $user.samaccountname)
   $params = @{
    Identity = $user.ObjectGUID
    MemberOf = $StudentGroup
    Confirm  = $false
    WhatIf   = $WhatIf
   }
   Add-ADPrincipalGroupMembership @params
  }
 }
 end {
  $grpObj = Get-ADGroupMember -Identity $StudentGroup
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $StudentGroup, $grpObj.count)
 }
}

function Connect-ADSession {
 # AD Domain Controller Session
 $adCmdLets = @(
  'Add-ADPrincipalGroupMembership'
  'Get-ADGroupMember'
  'Get-ADUser'
  'Remove-ADGroupMember'
 )
 $adSession = New-PSSession -ComputerName $dc -Credential $ADCredential
 Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber | Out-Null
}

function Remove-GroupMembers {
 Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $StudentGroup)
 Get-ADGroupMember -Identity $StudentGroup |
 ForEach-Object {
  Remove-ADGroupMember -Identity $StudentGroup -Members $_.samaccountname -Confirm:$false -WhatIf:$WhatIf
 }
}
function Get-jsonData ($obj) {
 $propNames = ($obj.teachers | Get-Member -MemberType NoteProperty | Select-Object Name).name
 foreach ($name in $propNames) {
  $obj.teachers.$name
 }
}

function Get-SamidsFromJson {
 begin {
  'SqlServer' | Add-Module
  $sisParams = @{
   Server     = $SISServer
   Database   = $SISDatabase
   Credential = $SISCredential
  }
  $regularSceduleSql = Get-Content -Raw -Path .\sql\RegularSchedule.sql
  $blockScheduleSql = Get-Content -Raw -Path .\sql\BlockSchedule.sql
 }
 process {
  $courseNums = ($_.course -join ',')
  if ($_.type -eq "regular") { $sql = $regularSceduleSql -f $_.id, $courseNums }
  if ($_.type -eq "block") { $sql = $blockScheduleSql -f $_.id, $courseNums }
  Write-Verbose ('{0},[{1}],[{2}],[{3}],[{4}]' -f $MyInvocation.MyCommand.Name, $_.id, $_.name, $_.type, $courseNums)
  $ids = Invoke-Sqlcmd @sisParams -Query $sql
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $_.name, $ids.count)
  $ids
 }
}

# main
. .\lib\Add-Module.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun

$dc = Select-DomainController $DomainControllers
Connect-ADSession

if ($ClearGroup) { Remove-GroupMembers }
$jsonData = Get-jsonData (Get-Content -Path $TeacherCoursesJSON -Raw | ConvertFrom-Json)
$jsonData | Get-SamidsFromJson | Add-GroupMember

Show-TestRun