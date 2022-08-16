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
 [int[]]$TeacherIDs,
 [Alias('wi')]
 [switch]$WhatIf
)


function Add-GroupMember {
 begin {
  Write-Host ('{0}' -f $MyInvocation.MyCommand.Name)
 }
 process {
  $filter = 'employeeId -eq {0}' -f $_.id
  $user = Get-ADUser -Filter $filter
  if ($user) {
   Write-Verbose ('{0},{1}' -f $MyInvocation.MyCommand.Name, $user.samaccountname)
   $params = @{
    Identity = $user.ObjectGUID
    MemberOf = $StudentGroup
    Confirm  = $false
    WhatIf   = $WhatIf
   }
   Add-ADPrincipalGroupMembership @params
  }
 }
}

function Connect-ADSession {
 # AD Domain Controller Session
 $adCmdLets = @(
  'Add-ADGroupMember'
  'Get-ADGroupMember'
  'Get-ADUser'
  'Remove-ADGroupMember'
 )
 $adSession = New-PSSession -ComputerName $dc -Credential $ADCredential
 Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber | Out-Null
}

function Get-Students {
 $sql = (Get-Content -Path .\sql\AdobeStudents.sql -Raw) -f ($TeacherIDs -join ',')
 $params = @{
  Server     = $SISServer
  Database   = $SISDatabase
  Credential = $SISCredential
  Query      = $sql
 }
 Invoke-Sqlcmd @params
}

function Remove-GroupMembers {
 Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $StudentGroup)
 Get-ADGroupMember -Identity $StudentGroup |
 ForEach-Object {
  Remove-ADGroupMember -Identity $StudentGroup $_ -Confirm:$false -WhatIf:$WhatIf
 }
}

# main
. .\lib\Load-Module.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun

'SQLServer' | Load-Module
$dc = Select-DomainController $DomainControllers
Connect-ADSession

Remove-GroupMembers

$stus = Get-Students
$stus.count
$stus | Add-GroupMember
$stus.id -join ','

Show-TestRun