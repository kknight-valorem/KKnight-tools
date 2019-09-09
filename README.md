# KKnight-tools
Collection of PowerShell tools I've created for managing Azure.
For more information read the code or load the module and use Get-Help <function>

Set-Scopes.ps1
    Set of funtions that create a list of scopes that may be used with both Manage-Policy and Manage-Roles.
    You set thes to the subscription Ids for your environment.
    It assumes you have seperate subscriptions for dev, test, production.

Manage-Roles - all you do is download it and run it (or load it ". .\Manage-Roles.ps1") 
    Get-RoleActions - retrieves the actions for a given role so you may edit them
    Get-RoleScopes - retrieves the list of scopes for a given role
    New-Role - allows you to create a new role and pass in a list of Actions as well as specify scope

Manage-Policy - all you do is download it and run it (or load it ". .\Manage-Roles.ps1") 
    Get-Policy - retrieves a policy file so you may edit it
    Set-Policy - Creates or Update a policy file for a set of subscriptions 
    New-PolicyRGassignment - assigns a subscription policy to a specific resource group