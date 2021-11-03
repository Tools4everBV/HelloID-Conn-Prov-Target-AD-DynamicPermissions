$permissions = @(
    @{
        DisplayName = "Dynamic Department";
        Identification = @{
            Reference = "Department";
        }
    }
)
Write-Output $permissions | ConvertTo-Json -Depth 10
