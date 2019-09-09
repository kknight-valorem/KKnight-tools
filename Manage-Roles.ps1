<# Manage-Roles.ps1 
#   This powershell will get a role and load the definition into a text file for editting

Next pass try reconstructing a new object from scratch.
Then try Azure RM per below from Zak

#Modify a custom role manually-ish
$role = Get-AzureRmRoleDefinition "[Hands-on Labs] PostgreSQL on Azure migrate v2"
$role.AssignableScopes.Add("/subscriptions/67b382a3-812f-43a7-be07-a9daa820258b")
$role.Actions.remove("Microsoft.Resources/subscriptions/*/read")
$role.Actions.remove("Microsoft.Resources/subscriptions/*/write")
$role.Actions.remove("Microsoft.Resources/subscriptions/*/action")
Set-AzureRmRoleDefinition -Role $role
Get-AzureRmRoleDefinition -Name "[Hands-on Labs] PostgreSQL on Azure migrate v2" | ConvertTo-Json

In PowerShell, use the Get-AzProviderOperation command to get the list of operations for the Microsoft.Support resource provider. 
It's helpful to know the operations that are available to create your permissions. 
You can also see a list of all the operations at Azure Resource Manager resource provider operations.
Get-AzProviderOperation "Microsoft.Support/*" | FT Operation, Description -AutoSize 
# FT is an alias for Format-Table
############################################################################################>
function Get-RoleScopes {
<#
.Synopsis
Output a role's scopes to a text file.

.Description
This function will output the scopes (subscriptions) to a text file

.Parameter Role
Required - name of the role you want to get the actions from

.Parameter scopesfile
Optional - text file to output role actions too.  Def = Role_scopes.txt 
    
#>
Param ( [Parameter(Mandatory=$True)] [string] $role, [string] $scopesfile, [string] $subid )

If ($scopesfile -eq "") { $scopesfile = 'Role_scopes.txt'; }
If ($subid -ne ""){
    $subdef = Get-AzSubscription -SubscriptionId $subid;
    Select-AzContext -Name $subdef.Name
}

# Get the current role definitoin
$roledef = Get-AzRoleDefinition -Name $role

# Open the $scopesfile
try { Set-Content -Path $scopesfile -Value $null }
catch { write-output "File $scopesfile is in use. Please close it first then run this again. Exiting."; Return 0}

# write the scopes to the $scopesfile
foreach ($scope in $roledef.AssignableScopes) {Add-Content -Path $scopesfile -Value $scope }

Write-output """$role""'s scopes have been written to $scopesfile"
Return $roledef
}
function Get-RoleActions {
<#
.Synopsis
Output a role's actions to a text file.

.Description
This function will output the permissions (actions) to a text file which you may then
edit and use the New-Role or Update-Role function to create or modify a role.

.Parameter Role
Required - name of the role you want to get the actions from. 

.Parameter actionsfile
Optional - text file to output role actions too.  Def = Role_actions.txt 

#>
Param ( [Parameter(Mandatory=$True)] [string] $role, [string] $actionsfile, [string] $subid )

If ($actionsfile -eq "") { $actionsfile = 'Role_actions.txt'; }
If ($subid -ne ""){
    $subdef = Get-AzSubscription -SubscriptionId $subid;
    Select-AzContext -Name $subdef.Name
}

# Get the current role definitoin
$roledef = Get-AzRoleDefinition -Name $role

# Open the $actionsfile
try { Set-Content -Path $actionsfile -Value $null }
catch { write-output "File $actionsfile is in use. Please close it first then run this again. Exiting."; Return 0}

# write the actions to the $actionsfile
foreach ($action in $roledef.Actions) {Add-Content -Path $actionsfile -Value $action }

Write-output """$role""'s actions have been written to $actionsfile"
Return $roledef
}

function New-Role {
<#
.Synopsis
Create a new role based on Azure actions entered in a text file.
Use Get-RoleActions to dump out an existing roles actions to a text file for editting.

.Description
Create a new role based on Azure actions entered in a text file.
Use Get-RoleActions to dump out an existing roles actions to a text file for editting.

.Parameter Role
Name for the Role will also be the description.

.Parameter actionsfile
Text file with list of permissions "actions".  Use Get-RoleActions to dump out an existing roles actions to a text file for editting.

.Parameter scopegroup
    "all"  = "prod","test","dev","misc","test1"
    "prod" = all HOL production subscriptions 
    "test" = all 5 HOL test subscriptions 
    "dev"  = all HOL development subscriptions
    "misc" = weird miscelleneous subscriptions
    "test1"= useful for testing before populating to all test
    "test4"= useful for testing before populating to all test
#>
    Param ( [Parameter(Mandatory=$True)] [string] $role, 
            [Parameter(Mandatory=$True)] [string] $actionsfile,
                                         [string] $scopegroup )

# Get the current role definitoin
if ($scopegroup -eq "" ){ $scopegroup = 'test4' } # Microsoft Managed Labs Valorem (test) - 4 

$roledef = New-Object -type Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition;
$roledef.Id = $null
$roledef.IsCustom = $true
$roledef.Name = $role
$roledef.Description = $role

# Load up the AssignableScopes = list of "/subscriptions/<subid>" from the scope
If ($scopegroup.ToLower() -notin "all","prod","test","dev","misc","test1","test4") { Write-Output "Invalid scope Exiting. Use one of the following [all,prod,test,dev,misc,test1,test4]"; Exit 1}

# update scope from $scope
$scope = @();
switch ($scopegroup) {
    all   { $scope = Set-ScopeAll   }
    prod  { $scope = Set-ScopeProd  }
    test1 { $scope = Set-ScopeTest1 }
    test4 { $scope = Set-ScopeTest4 }
    test  { $scope = Set-ScopeTest  }
    dev   { $scope = Set-ScopeDev   }
    misc  { $scope = Set-ScopeMisc  }
    Default { $scope = Set-ScopeTest };
}
$roledef.AssignableScopes = $scope;

# load up the actions from the text file
foreach($line in [System.IO.File]::ReadLines($actionsfile)) {
    $roledef.Actions += $line;
}

$roledef = New-AzRoleDefinition -Role $roledef

Write-output "$role [Id= $($roledef.Id) ] = $created for scope $scope"
Return $roledef
}

##############################################################################
# Main Program
##############################################################################
. ./Set-Scopes.ps1

#set the default subscription context to retrive the role from so we can write out the actions to a text file
$subid      = '59914dd5-2e07-4f07-bb07-0813a6406317'; # Microsoft Managed Labs Valorem (test) - 4
$subid      = "e204f082-7c50-42fe-b6bc-7d98a26b973d"; # Microsoft Managed Labs Valorem (test) - 1
$tenantid   = "fa23f4b5-cee9-4c9e-a774-d31b0f10c151"; # Cloud Platform Immersion Labs (cloudplatimmersionlabs.onmicrosoft.com)
if ($role -eq "") { write-output "Role parameter required."; Exit 1 }
if ($newrole -eq "") {$newrole = $role;}

# login if needed
$azaccount = Get-AzContext;
If ($azaccount.Subscription.Id -ne $subid) { Connect-AzAccount -Subscription $subid -Tenant $tenantid; }
Select-AzContext -Name "Microsoft Managed Labs Valorem (test) - 1 (e204f082-7c50-42fe-b6bc-7d98a26b973d) - kknight@valorem.com"
# Select-AzContext -Name "Microsoft Managed Labs Valorem (test) - 4 (59914dd5-2e07-4f07-bb07-0813a6406317) - kknight@valorem.com"

Write-output ""
Write-output "Use Get-RoleActions  -role '[Hands-on Labs] Cosmos DB' -actionsfile 'CosmosDB-actions.txt'"
Write-output "Use Get-RoleScopes   -role '[Hands-on Labs] Cosmos DB' -scopesfile 'CosmosDB-scopes.txt'"
write-output "Use New-Role -role '[Hands-on Labs] Cosmos DB' -actionsfile 'CosmosDB-actions.txt' -scope test"
