<# Manage-Policy.ps1 

    This powershell will create policy functions that allow you to manage polices in the HOL platform.
    It will then apply the updated policy to the subscriptions you specify in scope.

    You use it by running it or "loading it" . .\Manage-Policy.ps1
    It will they output examples of the functions.
    For each function you may use "Get-Help <function>" to get more information.

#>

Function Get-Policy {
<#
.Synopsis
Get a policy definiton and assignments

.Description
This function will output the policy definiton to a text file (optional)

.Parameter policy
Required - name of the policy

.Parameter policyfile
Optional - text file to output Policy definition too

.Parameter subid
Optional - specific subscription to look at
#>

Param ( [Parameter(Mandatory=$True)] [string] $policy, [string] $policyfile, [string] $subid )

If ($subid -ne "") { Set-AzContext -Subscription $subid }

# Get the current policy definition
$policydef = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq $policy }

If ($policydef.name -ne $null) 
     {Write-Output $policydef}
else {Write-Output "Policy $policy not found."}

Return $policydef
}

Function Set-Policy {
    <#
    .Synopsis
    Update or Creates a policy definiton
    
    .Description
    Set-Policy will cycle through all the subscriptions defined by -scopeGroup and create or update 
    the policy based on the Json file supplied. This function will return 1 if success else 0.
    
    .Parameter name
    Required - name of the policy
    
    .Parameter policydefinitionfile
    Required - text file to read the Policy definition from
    
    .Parameter scopeGroup
    Optional - must be one of the following that denote the list of subscripitons to apply the policy too
        Defaults to "test"
        "all"   - will set scope to prod + test + dev + misc
        "prod"  - any subscription with 'prod' in the name
        "test"  - test1..test5
        "test1" - only test1
        "test4" - only test4
        "dev"   - all development subscriptions
        "misc"  - weirdo subscriptions

    #>
    
    Param ( [Parameter(Mandatory=$True)] [string] $name, 
            [Parameter(Mandatory=$True)] [string] $definitionfile, 
                                         [string] $scopeGroup )

    $tenantId   = "fa23f4b5-cee9-4c9e-a774-d31b0f10c151";   # Cloud Platform Immersion Labs (cloudplatimmersionlabs.onmicrosoft.com)
    Write-Output "Creating policy '$name' from file $definitionfile"

    If ($scopeGroup -eq "") {$scopeGroup = "test"};
    If ($scopeGroup.ToLower() -notin "all","prod","test","dev","misc","test1","test4") {
        Write-Output "Invalid scopeGroup parameter, please choose one of the following.";
        Write-Output 'all,prod,dev,misc,test,test1,test4';
        Return 0}

    # update scope from $scope
    $scope = @();
    switch ($scopeGroup) {
        all   { $scope = Set-ScopeAll   }
        prod  { $scope = Set-ScopeProd  }
        test4 { $scope = Set-ScopeTest4 }
        test1 { $scope = Set-ScopeTest1 }
        test  { $scope = Set-ScopeTest  }
        dev   { $scope = Set-ScopeDev   }
        misc  { $scope = Set-ScopeMisc  }
        Default { Write-Output "logic error in switch on value $scopeGroup"; Return 0 };
    }

    foreach($sub in $scope) {
        try {
            $subid = $sub.Substring(15,($sub.Length-15)) 
            $subdef = Set-AzContext -SubscriptionId $subid -TenantId $tenantId
            Write-output "---------- Setting policy '$name' for subscription $($subdef.Subscription.Name) ----------"
            New-AzPolicyDefinition -Name $name `
                -DisplayName $name `
                -Policy $definitionfile `
                -Metadata '{"category":"Lab"}'
        }
        catch {write-output "New-AzPolicyDefinition error - $_"; Exit 0}
    } 

    Write-output """$name"" policy has been created for $scopeGroup subscriptions."

    Return 1
    }

Function New-PolicyRGassignment {
<#
.Synopsis
Assigns an existing policy to a given scope

.Description
Set-Policy will cycle through all the subscriptions defined by -scopeGroup and create or update 
the policy based on the Json file supplied. This function will return 1 if success else 0.

.Parameter name
Required - name of the policy

.Parameter rg
Required - resource group to apply policy too

#>
        
Param ( [Parameter(Mandatory=$True)] [string] $name, 
        [Parameter(Mandatory=$True)] [string] $rg )

# Get a reference to the resource group that will be the scope of the assignment
$rgdef = Get-AzResourceGroup -Name $rg

# Get a reference to the built-in policy definition that will be assigned
$policydef = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq $name }

$assignmentName = $name + '-' + $rg 

Write-Output "Creating assignment "
# Create the policy assignment against your resource group
New-AzPolicyAssignment -Name $assignmentName -DisplayName $name -Scope $rgdef.ResourceId -PolicyDefinition $policydef

}

##############################################################################
# Main Program
##############################################################################

# Load the subscription scope functions
. ./Set-Scopes.ps1

$subid      = "59914dd5-2e07-4f07-bb07-0813a6406317"; # Microsoft Managed Labs Valorem (test) - 4
$subid      = "e204f082-7c50-42fe-b6bc-7d98a26b973d"; # Microsoft Managed Labs Valorem (test) - 1
$tenantid   = "fa23f4b5-cee9-4c9e-a774-d31b0f10c151"; # Cloud Platform Immersion Labs (cloudplatimmersionlabs.onmicrosoft.com)

# login if needed
$azaccount = Get-AzContext;
If ($azaccount.Subscription.Id -ne $subid) { Connect-AzAccount -Subscription $subid -Tenant $tenantid; }
Select-AzContext -Name "Microsoft Managed Labs Valorem (test) - 1 ($subid) - kknight@valorem.com"
# Select-AzContext -Name "Microsoft Managed Labs Valorem (test) - 4 ($subid) - kknight@valorem.com"

# ensure we can use the Policy powershell commandlets
Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'

$policy     = "Deny Postgres";
$txtfile    = 'Policy_Definition.json';

Write-output "****** Manage Policy loaded ******"
Write-output "Use Get-Policy -policy 'Deny Postgress' -policyfile 'DenyPostgres.json' -subid e204f082-7c50-42fe-b6bc-7d98a26b973d"
Write-output "Use Set-Policy -policy 'Deny Postgress' -policyfile 'DenyPostgres.json' -scopeGroup test"
Write-output "Use New-PolicyRGassignment -name 'Deny Postgress' -rg 'rg123456'"

Exit 1

<#
Write-output "Use New-PolicyRGassignment -name 'Deny Postgress' -rg 'DenyPostgresAssignments.json'"
Write-output "Use Set-PolicyAssignment  -name 'Deny Postgress' -assignmentsfile 'DenyPostgresAssignments.json'"


Extra code from researching

$policydef = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq $policy }

# Open the $txtfile
try { Set-Content -Path $txtfile -Value $null }
catch { write-output "File $txtfile is in use. Please close it first then run this again. Exiting."; Exit 1}

# write the actions to the $txtfile
$policyrulejson = $policydef.Properties.policyRule | ConvertTo-Json
Add-Content -Path $txtfile -Value $policyrulejson

# OK time for User to update policy actions 
Write-output """$policy""'s policy rule has been written to $txtfile"
Write-output "You may now edit $txtfile and save the results."
$scope_q = Read-host -Prompt "Enter scope (All, Prod, Test, Dev, Misc) to update or n to exit"


    # update policy Actions based on text file
    $newPolicyText = [IO.File]::ReadAllText($definitionfile);
    try {$newPolicy = $newPolicyText | ConvertFrom-Json;}
    catch {write-output "Json conversion error - $($_.error)"; Exit 0}

#>