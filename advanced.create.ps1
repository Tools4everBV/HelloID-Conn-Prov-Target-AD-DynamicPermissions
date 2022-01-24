#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = ConvertFrom-Json $person

$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

#Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Change mapping here
    #Correlation
    $correlationPersonField = ($config.correlationPersonField | Invoke-Expression)
    $correlationAccountField = $config.correlationAccountField
#endregion Change mapping here

#region Execute
try{
    #Find AD account by employeeID attribute
    $filter = "($($correlationAccountField)=$($correlationPersonField))"
    #Write-Information "LDAP Filter: $($filter)"

	$account = Get-ADUser -LdapFilter $filter -Property sAMAccountName -Server $pdc

    if ($null -eq $account) { throw "Failed to return an account" }

    Write-Information "Account correlated to $($account.sAMAccountName)"

	$auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account correlated to $($account.sAMAccountName)"
                IsError = $false
            })

    $success = $true
}
catch
{
    $auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account failed to correlate:  $_"
                IsError = $true
            })
	#Write-Error $_
}
#endregion Execute

#region build up result
$result = [PSCustomObject]@{
    Success= $success
    AccountReference= $account.SID.Value
    AuditLogs = $auditLogs
    Account = $account
}

Write-Output $result | ConvertTo-Json -Depth 10
#endregion build up result