$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json

$o = $operation | ConvertFrom-Json

$eRef = $entitlementContext | ConvertFrom-Json

$currentPermissions = @{}
foreach($permission in $eRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

$success = $true
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$subPermissions = New-Object Collections.Generic.List[PSCustomObject]

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

$desiredPermissions = @{}
if (-Not($o -eq "revoke"))
{
    foreach($contract in $p.Contracts) {
        if($contract.Context.InConditions) {
            $group_sAMAccountName = Invoke-Expression "`"$($config.config1.name)`""
            $desiredPermissions[$group_sAMAccountName] = $group_sAMAccountName
        }
    }
}

if ($c.config1.verbose) { Write-Verbose -Verbose ("Defined Permissions: {0}" -f ($desiredPermissions.keys | ConvertTo-Json)) }
if ($c.config1.verbose) { Write-Verbose -Verbose ("Existing Permissions: {0}" -f $entitlementContext) }

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value
            Reference = [PSCustomObject]@{ Id = $permission.Name }
    })

    if(-Not $currentPermissions.ContainsKey($permission.Name))
    {
        # Add user to Membership
        $permissionSuccess = $true
        if(-Not($dryRun -eq $true)) {
            try {
                #Note:  No errors thrown if user is already a member.
                if ($c.config1.verbose) { Write-Verbose -Verbose ("Setting Permissions: {0} to user {1} on DC {2}" -f $permission.Name, $aRef, $pdc) }
                $permissionName = $permission.Name.replace("+","")
                Add-ADGroupMember -Identity $permissionName -Members @($aRef) -server $pdc -ErrorAction 'Stop'
                if ($c.config1.verbose) { Write-Verbose -Verbose ("Successfully Granted Permission to: {0}" -f $permission.Name) }
                # this message should be the audit message!
            } catch {
                $permissionSuccess = $false
                $success = $false
                # Log error for further analysis.  Contact Tools4ever Support to further troubleshoot
                Write-Verbose -Verbose ("Error Granting Permission for Group [{0}]:  {1}" -f $permission.Name, $_)
                # this message should be the audit message!
            }
        }

        $auditLogs.Add([PSCustomObject]@{
            Action = "GrantDynamicPermission"
            Message = "Granted membership: {0}" -f $permission.Name
            IsError = -NOT $permissionSuccess
        })
    }    
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{}
foreach($permission in $currentPermissions.GetEnumerator()) {    
    if(-Not $desiredPermissions.ContainsKey($permission.Name) -AND $permission.Name -ne "No Groups Defined")
    {
        # Revoke Membership
        if(-Not($dryRun -eq $true))
        {
            $permissionSuccess = $true
            try {
                $permissionName = $permission.Name.replace("+","")
                Remove-ADGroupMember -Identity $permissionName -Members @($aRef) -Confirm:$false -server $pdc -ErrorAction 'Stop'
            }
            # Handle issue of AD Account or Group having been deleted.  Handle gracefully.
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
                Write-Verbose -Verbose "Identity Not Found.  Continuing"
                Write-Verbose -Verbose $_.ScriptStackTrace
            } catch {
                $permissionSuccess = $false
                $success = $false
                # Log error for further analysis.  Contact Tools4ever Support to further troubleshoot.
                Write-Verbose -verbose ("Error Revoking Permission from Group [{0}]:  {1}" -f $permission.Name, $_)
            }
        }
        
        $auditLogs.Add([PSCustomObject]@{
            Action = "RevokeDynamicPermission"
            Message = "Revoked membership: {0}" -f $permission.Name
            IsError = -Not $permissionSuccess
        })
    } else {
        $newCurrentPermissions[$permission.Name] = $permission.Value
    }
}

# Update current permissions
# Updates not needed for Group Memberships.

# Handle case of empty defined dynamic permissions.  Without this the entitlement will error.
if ($o -match "update|grant" -AND $subPermissions.count -eq 0)
{
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = "No Groups Defined"
            Reference = [PSCustomObject]@{ Id = "No Groups Defined" }
    })
}

#region Build up result
$result = [PSCustomObject]@{
    Success = $success
    SubPermissions = $subPermissions
    AuditLogs = $auditLogs
}
Write-Verbose -Verbose ($result | ConvertTo-Json -Depth 10)
Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion Build up result