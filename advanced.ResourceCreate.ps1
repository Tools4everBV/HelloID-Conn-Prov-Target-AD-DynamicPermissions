$rRef = $resourceContext | ConvertFrom-Json
$config = ConvertFrom-Json $configuration
$organizationalUnit = $config.config1.dn_ou
$prefix = Invoke-Expression "`"$($config.config1.name)`""
$alsoLogQueries = $false # Verbose logging must be enabled as well
$type = "department"
$success = $false

$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

# In preview only the first 10 items of the SourceData are used
foreach ($item in $rRef.SourceData) {
    $contract = @{$type = $item}   # Little bit of fiddling to match the field mapping
    $groupName = Invoke-Expression "`"$($config.config1.name)`""

    if (-Not($groupName -eq $prefix)) {
        try {
            $groupSamaccountName = $groupName.replace("+","")
            if ($config.config1.verbose -and $alsoLogQueries) { Write-Verbose -Verbose -Message "Checking if group '$groupName' with samaccountname '$groupSamAccountName' exists in the Active Directory..." }
            $group = $null
            $group = Get-ADGroup -Identity $groupSamaccountName
            if ($config.config1.verbose -and $alsoLogQueries) { Write-Verbose -Verbose -Message "Not creating group '$groupName' because it already exists." }
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # If resource does not exist
            if ($null -eq $group) {
                $splat = @{
                    Name = $groupName
                    Description = $groupName
                    DisplayName = $groupName
                    GroupCategory = 'Security'  # Or 'Distribution'
                    GroupScope = 'Global' # Or 'DomainLocal', 'Universal'
                    SamAccountName = $groupSamaccountname
                    Path = $organizationalUnit
                    Server = $pdc
                    Confirm = $false
                }
                if ($config.config1.verbose) { Write-Verbose -Verbose -Message "Group '$groupName' not found in the Active Directory. Group will be created with the following properties: $($splat | ConvertTo-Json)" }

                if (-Not($dryRun -eq $true)) {
                    try {
                        $null = New-ADGroup @splat
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Creating resource for $type '$groupName' with samaccountname '$GroupSamaccountname'";
                            Action  = "CreateResource"
                            IsError = $false
                        })
                    } catch {
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Creating resource for $type '$groupName' with samaccountname '$GroupSamaccountname'failed: $($_.Exception.Message) - $($_.ScriptStackTrace)";
                            Action  = "CreateResource"
                            IsError = $true
                        })
                    }
                }
            } else {
                if ($config.config1.verbose) { Write-Verbose -Verbose -Message "Unknown exception while looking up group '$groupName'" }
                $auditLogs.Add([PSCustomObject]@{
                    Message = "Creating resource for $type '$groupName' with samaccountname '$GroupSamaccountname' failed: $($_.Exception.Message) - $($_.ScriptStackTrace)";
                    Action  = "CreateResource"
                    IsError = $true
                })
            }
        } catch {
            $auditLogs.Add([PSCustomObject]@{
                Message = "Creating resource for $type '$groupName' with samaccountname '$GroupSamaccountname' failed: $($_.Exception.Message) - $($_.ScriptStackTrace)";
                Action  = "CreateResource"
                IsError = $true
            })
            if ($config.config1.verbose) { Write-Verbose -Verbose -Message "Failed to create group $($groupName): $($_.Exception.Message) - $($_.ScriptStackTrace)" }
        }
    }
}
$success = $true

# Send results
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs
}
Write-Output $result | ConvertTo-Json -Depth 10