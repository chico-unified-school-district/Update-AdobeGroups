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
function Get-jSonData ($obj) {
 $propNames = ($obj.teachers | Get-Member -MemberType NoteProperty | Select-Object Name).name
 foreach ($name in $propNames) {
  $obj.teachers.$name
 }
}

function Get-SamidsFromJson {
 begin {
  'SqlServer' | Load-Module
  $sisParams = @{
   Server     = $SISServer
   Database   = $SISDatabase
   Credential = $SISCredential
  }
  $baseSql = Get-Content -Raw -Path .\sql\AdobeStudents.sql
 }
 process {
  $courseNums = ($_.course -join ',')
  $sql = $baseSql -f $_.id, $courseNums
  Write-Host ('{0},[{1}],[{2}],[{3}]' -f $MyInvocation.MyCommand.Name, $_.id, $_.name, $courseNums)
  $ids = Invoke-Sqlcmd @sisParams -Query $sql
  Write-Host ('{0},[{1}],Total: {2}' -f $MyInvocation.MyCommand.Name, $_.name, $ids.count)
  $ids
 }
}

function Get-SiteQueryFiles {
 Get-ChildItem -Path .\sql\SiteQueries -Filter *.Sql
}

function New-QueryObject {
 process {
  # $_
  New-Object PSObject -Property @{
   fileName = $_.name
   SqlCmd   = ( $_ | Get-Content -Raw )
  }
 }
}

function Get-SamidsFromSql {
 begin {
  'SqlServer' | Load-Module
  $sisParams = @{
   Server     = $SISServer
   Database   = $SISDatabase
   Credential = $SISCredential
  }
 }
 process {
  $sql = $_.SqlCmd
  Write-Host ('{0}' -f $MyInvocation.MyCommand.Name, $_.fileName)
  $ids = Invoke-Sqlcmd @sisParams -Query $sql
  Write-Host ('{0},{1},Total: {2}' -f $MyInvocation.MyCommand.Name, $_.fileName, $ids.count)
  $ids
 }
}

# main
. .\lib\Load-Module.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun

$dc = Select-DomainController $DomainControllers
Connect-ADSession

# Remove-GroupMembers
# $courseInfo = Get-jSonData (Get-Content -Path $TeacherCoursesJSON -Raw | ConvertFrom-Json)
# $courseInfo | Get-SamidsFromJson | Add-GroupMember
Get-SiteQueryFiles | New-QueryObject | Get-SamidsFromSql | Add-GroupMember

Show-TestRun