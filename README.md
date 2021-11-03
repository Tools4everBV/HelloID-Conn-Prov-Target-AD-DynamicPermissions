# HelloID-Conn-Prov-Target-AD-DynamicPermissions
Dynamic permissions scripts for Department, Function &amp; Department-Function groups (WIP)

We added an advanced configuration set, which can be used to setup DRM for departments. For example, the settings can be filled in as follows:
- Person Correlation Field: $p.Custom.EmployeeId
- Account Correlation Field: employeeID
- Verbose Logging: True
- Department Group Name: OE-AFD-$($contract.Department.ExternalId)
- Department Group Location: OU=OE-AFD,DC=Customer,DC=local

If you would like to use this connector for another attribute, like title, you only have to edit the type variable in the script.
