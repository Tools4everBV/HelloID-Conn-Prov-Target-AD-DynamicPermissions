$serverFQDN = $($c.serverFQDN)
$prefix = $($c.groupPrefix)

$rRef = $resourceContext | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$path = "<container>"

# In preview only the first 10 items of the SourceData are used
foreach ($title in $rRef.SourceData) {
    
    $groupName = $prefix + $title.ExternalId
    
    if (-Not([string]::IsNullOrEmpty($title.ExternalId))) {
        Write-Verbose -Verbose $resourceContext
        try {
            $group = $null
            $group = Get-ADGroup -Identity $groupName    
            #Write-Verbose -Verbose "$groupName found"
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # If resource does not exist
            if ($null -eq $group) {
                Write-Warning "Group Not Found - $($groupName). Group will be created"    
                if (-Not($dryRun -eq $True)) {
                    # Write resource creation logic here
                    $null = New-ADGroup -name $groupName -groupscope Global -path $path -server $serverFQDN
                    
                }
                $auditLogs.Add([PSCustomObject]@{
                        Message = "Creating resource for department $($groupName)";
                        Action  = "CreateResource"
                        IsError = $False;
                    });
            }
        }
        catch {
            Write-Warning "Failed to create group $($groupName): $($_.Exception.Message)";
        }
    }
    
}
$success = $True;
# Send results
$result = [PSCustomObject]@{
    Success   = $success;
    AuditLogs = $auditLogs;
};
Write-Output $result | ConvertTo-Json -Depth 10;
