$p = $person | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$pRef = $entitlementContext | ConvertFrom-json;


$c = $configuration | ConvertFrom-Json;
$serverFQDN = $($c.serverFQDN)
$groupPrefix = $($c.groupPrefix)

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json;

if ($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant";

}

$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject];

$currentPermissions = @{};
foreach ($permission in $pRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName;
}

$desiredPermissions = @{};
foreach ($contract in $p.Contracts) {
    if ($contract.Context.InConditions) {
        $desiredPermissions[$contract.Costcenter.Code] = $contract.Costcenter.Name;
    }
}

# Compare desired with current permissions and grant permissions
foreach ($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value;
            Reference   = [PSCustomObject]@{ Id = $permission.Name };
        });

    if ($currentPermissions.ContainsKey($permission.Name)) {
        Write-Verbose -Verbose "CurrentPermissions already contains $($permission.Name) - $($permission.Value)"
    }

    if (-Not $currentPermissions.ContainsKey($permission.Name)) {
        Write-Verbose -Verbose "CurrentPermissions doesn't contain $($permission.Name) - $($permission.Value)"
    }

    if (-Not $currentPermissions.ContainsKey($permission.Name)) {
        try {
            # fetch the group first
            $groupname = $groupPrefix + $permission.Name;
                    
            #$group = Get-ADGroup -LDAPFilter "'(samaccountname=$($groupname))'" -server $serverFQDN
            $group = Get-ADGroup -Identity $groupName -server $serverFQDN
            Write-Verbose -Verbose ($group | ConvertTo-Json)
        
            if ($group) {
                #Write-Verbose -Verbose "Add-ADGroupMember -Identity $($permission.Value) -Members $($aRef) -Server $($serverFQDN)"
                #Add-ADGroupMember -Identity "'$($permission.Value)'" -Members $aRef -Server $serverFQDN
                $group | Add-ADGroupMember -Members $aRef -server $serverFQDN                
                
                $auditLogs.Add([PSCustomObject]@{
                        Action  = "GrantDynamicPermission";
                        Message = "Granted access to group $($permission.Value)";
                        IsError = $False;
                    });
                $success = $True;
            }               
        }
        catch {
            Write-Warning "Failed to grant: $($_.Exception.Message)";
        }
    }    
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{};
foreach ($permission in $currentPermissions.GetEnumerator()) {    
    if (-Not $desiredPermissions.ContainsKey($permission.Name)) {
        try {
            $groupname = $groupPrefix + $permission.Name;
            $group = Get-ADGroup -Identity $groupname -server $serverFQDN
            Write-Verbose -Verbose ($group | ConvertTo-Json)
            
            if ($group) {
                Write-Verbose -Verbose "Remove-ADGroupMember -Identity $($permission.Value) -Members $($aRef) -Server $($serverFQDN)"
                #Remove-ADGroupMember -Identity "'$($permission.Value)'" -Members $aRef -Server $serverFQDN -Confirm:$false
                $group | Remove-ADGroupMember -Members $aRef -server $serverFQDN -Confirm:$false

                $auditLogs.Add([PSCustomObject]@{
                        Action  = "RevokeDynamicPermission";
                        Message = "Revoked access from group $($permission.Value)";
                        IsError = $False;
                    });
                $success = $True;
            }
        }
        catch {
            Write-Warning "Failed to revoke: $($_.Exception.Message)";
        }
    }
    else {
        $newCurrentPermissions[$permission.Name] = $permission.Value;
    }
}

# Update current permissions
if ($o -eq "update") {
    foreach ($permission in $newCurrentPermissions.GetEnumerator()) {    
        $auditLogs.Add([PSCustomObject]@{
                Action  = "UpdateDynamicPermission";
                Message = "Updated access to department share $($permission.Value)";
                IsError = $False;
            });
    }
}

$success = $True;

# Send results
$result = [PSCustomObject]@{
    Success            = $success;
    DynamicPermissions = $dynamicPermissions;
    AuditLogs          = $auditLogs;
};
Write-Output $result | ConvertTo-Json -Depth 10;
