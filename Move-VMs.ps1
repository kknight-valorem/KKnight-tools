<# Move-VMs.ps1
.Synopsis
    In a resource group move all VMs in one location to another location
.Description
    Lists information on all VMs in a resource group, size, etc
.Parameter Name
    $rg - Required. Resource Group name.

.notes
    this is an example for getting a sorted formatted list of resource groups
    Get-AzResourceGroup | Sort Location,ResourceGroupName | Format-Table -GroupBy Location ResourceGroupName,ProvisioningState,Tags
    Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $rg | Format-Table
#>

Function Get-VMs {
<#
.Synopsis
    Lists information on all VMs in a resource group
.Description
    Lists information on all VMs in a resource group, size, etc
.Parameter Name
    $rg - Required. Resource Group name.

.notes
    this is an example for getting a sorted formatted list of resource groups
    Get-AzResourceGroup | Sort Location,ResourceGroupName | Format-Table -GroupBy Location ResourceGroupName,ProvisioningState,Tags
    Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $rg | Format-Table
#>
Param ([Parameter(Mandatory=$True)] [string] $rg)
    
    $vms = Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $rg
    $formatstring = "{0,15} {1,14} {2,16} {3,26} {4,11} {5,16} {6,20} {7,9}"
    $formatstring -F "VM","PowerState","Location","VmSize","AvailSet","Admin","OS","OSDiskGB" | Write-Output
    $formatstring -F "-----------","-----------","-----------","-----------","-----------","-----------","-----------","---------" | Write-Output
    foreach ($vm in $vms) {
        $vminfo = Get-AzVM -name $vm.ResourceName -Status
        $as = $false;
        if ($vminfo.AvailabilitySetReference -ne $null) {$as = $true}
        
        $formatstring -F `
            $vminfo.Name, `
            $vminfo.PowerState, `
            $vminfo.Location, `
            $vminfo.HardwareProfile.VmSize, `
            $as, `
            $vminfo.OSProfile.AdminUsername, `
            $vminfo.StorageProfile.ImageReference.Sku, `
            $vminfo.StorageProfile.osdisk.disksizegb | Write-Output
        write-output "      OSDisk = $($vminfo.StorageProfile.osdisk.Name)"
        foreach ($datadisk in $vminfo.StorageProfile.DataDisks) {
            write-output "    DataDisk = $($datadisk.Name), size = $($datadisk.DiskSizeGB)"
        }
        write-output ""
    }
}

Function Invoke-SnapshotVMs {
<#
.Synopsis
    For each VM in a resource group this will create a snapshot of the disks
.Description
    For each VM in a resource group in the $location this will spin down the VM if its running then 
    create a snapshot of the OS and Data disks.
.Parameter Name
    $rg - Required. Resource Group name.
#>

Param ( [Parameter(Mandatory=$True)] [string] $rg,
        [Parameter(Mandatory=$True)] [string] $location )
    
    $vms = Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $rg
    foreach ($vm in $vms) {
        $vminfo = Get-AzVM -name $vm.ResourceName -Status

        If ($vminfo.Location -eq $location) {
            write-output "$(get-date) - Working on $($vminfo.Name)"
            
            if ($vminfo.PowerState -eq "VM running") {
                Write-output "$(get-date) - Stopping VM $($vminfo.Name), please wait app 2 minutes"
                Stop-AzVM -ResourceGroupName $rg -Name $vminfo.Name -confirm:$false -Force
            }

            $snapshotconfig =  New-AzSnapshotConfig `
                -SourceUri $vminfo.StorageProfile.OsDisk.ManagedDisk.Id `
                -Location $location `
                -AccountType 'Standard_LRS' `
                -CreateOption copy

            $datetime = (Get-Date).ToString("yyyyMMddhhmm");
            $OSnapName = $vminfo.Name + "_OSnap_" + $datetime;
            write-output "Creating snap $OSnapName from $($vminfo.Name)'s OSDisk = $($vminfo.StorageProfile.osdisk.Name)"
            New-AzSnapshot `
                -ResourceGroupName $rg `
                -SnapshotName $OSnapName `
                -Snapshot $snapshotconfig `
                -Confirm:$false

            $datadisknum = 0;
            foreach ($datadisk in $vminfo.StorageProfile.DataDisks) {
                $datadisknum    = $datadisknum + 1;
                $datasnapname   = $vminfo.Name + "_Data" + $datadisknum + "_" + $datetime

                $snapshotconfig =  New-AzSnapshotConfig `
                -SourceUri $datadisk.ManagedDisk.Id `
                -Location $location `
                -AccountType 'Standard_LRS' `
                -CreateOption copy

                write-output "Creating snap $datasnapname from $($vminfo.Name)'s DataDisk = $datadisk"

                New-AzSnapshot `
                    -ResourceGroupName $rg `
                    -SnapshotName $datasnapname `
                    -Snapshot $snapshotconfig `
                    -Confirm:$false
            }
        }
    }
}

Function Copy-Snaps {
<#
.Synopsis
    For each snapshot in the $from location this will copy it to the $to region storage account
.Description
    If the storage account doesn't exits this will create it in the $to region.  Then for each snapshot 
    in a resource group in the $from location this will copy the snapshot to the blob storage account under
    the snaps container using the snap name and a .vhd extension.
    If the file already exists it will skip the copy.
.Parameter rg
    $rg - Required. Resource Group name
    $to_rg - Required. 
.Parameter to_rg
    $rg - Required. Resource Group name
    $to_rg - Required
.Parameter from
    $from - Required. Location we are moving from.  To get a list of valid locations use the following command
            Get-AzLocation |Format-Table
.Parameter to
    $to -   Required. Location we are moving to.  To get a list of valid locations use the following command
            Get-AzLocation |Format-Table
.Notes
    https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-copy-snapshot-to-storage-account 
#>
    
Param ( [Parameter(Mandatory=$True)] [string] $rg,
        [Parameter(Mandatory=$True)] [string] $to_rg, 
        [Parameter(Mandatory=$True)] [string] $from,
        [Parameter(Mandatory=$True)] [string] $to         )

    # Set the name of the storage account (limit 24 char) and the SKU name
    $azaccount  = Get-AzContext;
    if ($to.length -lt 16 ) 
        {$storageAccountName = "snap" + $to + $azaccount.Subscription.Id.Substring(0,4)}
    else {$storageAccountName = "snap" + $to.Substring(0,16) + $azaccount.Subscription.Id.Substring(0,4)}

    $skuName = "Standard_LRS"
    
    # Create the storage account if it doesn't exist
    $sa = Get-AzStorageAccount -ResourceGroupName $rg -Name $storageAccountName -ErrorAction:silentlycontinue
    if ($sa -eq $null) {
        Write-output "$(get-date) - Creating Storage Account $storageAccountName in $to"
        $sa = New-AzStorageAccount -ResourceGroupName $to_rg `
            -Name $storageAccountName `
            -Location $to `
            -SkuName $skuName
        }
    else {
        Write-Output ""
        $answer = Read-Host -Prompt "OK to move the listed VMs in $from_location to $to_location ?"
        if ($answer.ToLower() -eq "n" ) {write-output "exiting"; exit 1}
        if ($answer.ToLower() -eq "no") {write-output "exiting"; exit 1}
    }

    # Create the storage account container if it doesn't exist
    $storageContainerName = "snaps"
    $sacontext = New-AzStorageContext -StorageAccountName $storageAccountName
    $container = Get-AzStorageContainer -Name $storageContainerName -Context $sacontext -ErrorAction:silentlycontinue
    if ($container -eq $null) {
        Write-output "$(get-date) - Creating Storage Account container $storageAccountName / $storageContainerName"
        $container = New-AzStorageContainer -Name $storageContainerName -Context $sacontext
        }

    #Shared Access Signature expiry duration in seconds
    $sasExpiryDuration = "86400" # 24hrs

    #Provide the key of the storage account where you want to copy snapshot. 
    $storageAccountKey = Get-AzStorageAccountKey -ResourceGroupName $to_rg -Name $storageAccountName
    $sacontext         = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey[0].Value

    $snaps = Get-AzSnapshot -ResourceGroupName $rg
    foreach ($snap in $snaps) {
        #Provide the name of the VHD file to which snapshot will be copied.
        $destinationVHDFileName = $Snap.Name + ".vhd"

        # Check to see if the VHD copy of the snap is already there
        $blobfile = Get-AzStorageBlob -Container 'snaps' -Context $sacontext -Blob $destinationVHDFileName -ErrorAction:SilentlyContinue
        if ($blobfile -eq $null) {

            #Generate the SAS for the snapshot
            Write-output "$(get-date) - Generating 24hr access key for snapshot $($Snap.Name) please wait." 
            $sas = Grant-AzSnapshotAccess -ResourceGroupName $rg -SnapshotName $Snap.Name -DurationInSecond $sasExpiryDuration -Access Read 

            #Create the context for the storage account which will be used to copy snapshot to the storage account 
            $destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey[0].Value

            Write-Output "$(get-date) - Copying $($Snap.Name) to $to storage $storageAccountName / $storageContainerName"
            #Copy the snapshot to the storage account 
            
            Start-AzStorageBlobCopy `
                -AbsoluteUri    $sas.AccessSAS `
                -DestContainer  $storageContainerName `
                -DestContext    $destinationContext `
                -DestBlob       $destinationVHDFileName `
                -ConcurrentTaskCount 15
            
        }
        else { Write-Output "$destinationVHDFileName already exists, skipping." }        
        <# Note this will serialize the process and wait for the prior copy to complete

        Write-Output "$(get-date) - Getting state waiting for completion"
        Get-AzStorageBlobCopyState -Blob $destinationVHDFileName -Container $storageContainerName -Context $destinationContext -WaitForComplete
        
        Write-Output ""
        $answer = Read-Host -Prompt "Press Enter to continue."
        #>
    }

    return $storageAccountName
}

Function Create-VMs {
<#
.Synopsis
    For each VM OS Disk blob in the storage account create a VM with any associated data disks
.Description
    This function assumes you have used Snap-VMs and Copy-Snaps which will put all the VM disk snapshots in the
    destination storage account.  What this will do is look thru the Storage Account for OS disk volumes in the
    snap container that follow the format vmname + "_OSnap_" + datetime + "vhd".
    It will create a managed disk form the VHD find all related disks "_Data<n>_" where <n> is the attached disk #
    setup the subnet, virutal net, ip, nic and create the VM from all this mess.
    
    Note: Since the operation will use the same VM name the original will need to be deleted first.

.Parameter rg
    $rg                 - Required. Resource Group name.

.Parameter storageAccountName
    $storageAccountName - Required. The storarge account for the VMs

.Notes
    https://docs.microsoft.com/en-us/azure/virtual-machines/windows/create-vm-specialized 

#>
    
Param ( [Parameter(Mandatory=$True)] [string] $rg,
        [Parameter(Mandatory=$True)] [string] $old_rg,
        [Parameter(Mandatory=$True)] [string] $storageAccountName )

    # Set the name of the storage account and the SKU name
    $location           = (Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $rg).Location
    $storageAccountKey  = Get-AzStorageAccountKey -ResourceGroupName $rg -Name $storageAccountName
    $sacontext          = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey[0].Value
    $osDisks            = Get-AzStorageBlob -Container 'snaps' -Context $sacontext -Blob *_OSnap_*

    foreach ($osDisk in $osDisks) {
        $vmName = $osDisk.name.Substring(0, $osDisk.name.IndexOf('_OSnap_') );  

        If ($vmname -eq 'MSASP16Dev01') {

            Write-output "$(Get-Date) - Found $vmName's OS Disk $($osDisk.name)"
            
            $oldvm = Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $old_rg -Name $vmName -ErrorAction:SilentlyContinue
            $oldVmSize = $oldvm.Properties.hardwareProfile.vmSize
            if ($oldVMSize -eq $null) {$oldVmSize = 'Standard_D2s_v3'}
            $oldVmSize = 'Standard_D2s_v3'
            
            # Delete old VM so we don't have a name conflict
            if ($oldvm -ne $null) {
                Write-Output "$(Get-Date) - Removing $vmName in $from_location, please wait."
                Remove-AzVm -Name $vmName -Force -ResourceGroupName $rg -Confirm:$false
            }
          

            # Configure subnet then create vNet
            $subnetName = $vmName + '_subnet';
            $vNetName   = $vmName + "_vnet";
            $ipName     = $vmName + "_ip";
            $nicName    = $vmName + "_nic";
            $nsgName    = $vmName + "_nsg";
            $subnet = New-AzVirtualNetworkSubnetConfig `
                -Name $subnetName `
                -AddressPrefix 10.0.0.0/24

            # Removing VM scaffolding
            Write-output "$(Get-Date) - Removing VM $vmName's azure objects from $from_location if they exist to prevent name conflicts"
            $nic = Get-AzNetworkInterface -ResourceGroupName $old_rg -Name $nicName -ErrorAction:silentlycontinue
            if ($nic -ne $null) {
                Write-Output "$(get-date) - Removing nic $nicName from $($nic.Location)"
                Remove-AzNetworkInterface -ResourceGroupName $old_rg -Name $nicName -Force -Confirm:$false
            }
            $publicIp = Get-AzPublicIpAddress -ResourceGroupName $old_rg -Name $ipName -ErrorAction:silentlycontinue
            if ($publicIp -ne $null) {
                Write-Output "$(get-date) - Removing PublicIp $ipName from $($publicIp.Location)"
                Remove-AzPublicIpAddress -ResourceGroupName $old_rg -Name $ipName -Force -Confirm:$false
            }
            $vNet = Get-AzVirtualNetwork -ResourceGroupName $old_rg -Name $vNetName  -ErrorAction:silentlycontinue
            if ($vNet -ne $null) {
                Write-Output "$(get-date) - Removing vNet $vNetName from $($vNet.Location)"
                Remove-AzVirtualNetwork -ResourceGroupName $old_rg -Name $vNetName -Force -Confirm:$false
            }
            $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $old_rg -Name $nsgName -ErrorAction:silentlycontinue
            if ($nsg -ne $null) {
                Write-Output "$(get-date) - Removing nsg $nsgName from $($vNet.Location)"
                Remove-AzNetworkSecurityGroup -ResourceGroupName $old_rg -Name $vNetName -Force -Confirm:$false
            }




            # Creating VM scaffolding
            # vNet
            Write-Output "$(get-date) - Creating vNet $vNetName with subnet $subnetName in $Location location"
            $vNet = New-AzVirtualNetwork `
                -Name $vNetName  `
                -ResourceGroupName $rg `
                -Location $location `
                -AddressPrefix 10.0.0.0/16 `
                -Subnet $subnet 
            
            # nsg
            # create RDP rule to allow port 3389
            Write-Output "$(get-date) - Creating nsg $nsgName to allow RDP in $Location location"
            $rdpRule = New-AzNetworkSecurityRuleConfig -Name Rdp -Description "Allow RDP" `
                -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
                -SourceAddressPrefix Internet -SourcePortRange * `
                -DestinationAddressPrefix * -DestinationPortRange 3389
            $nsg = New-AzNetworkSecurityGroup `
                -ResourceGroupName $rg `
                -Location $location `
                -Name $nsgName `
                -SecurityRules $rdpRule
            
            # ip
            Write-Output "$(get-date) - Creating ipName $ipName in $Location location"
            $publicIp = New-AzPublicIpAddress -Name $ipName -ResourceGroupName $rg -Location $location -AllocationMethod Dynamic -ErrorAction:silentlycontinue
            
            #nic
            Write-Output "$(get-date) - Creating nicName $nicName in $Location location"
            $nic = New-AzNetworkInterface -ResourceGroupName $rg  -Name $nicName -Location $location -SubnetId $vNet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

            # Use the following Powershell AZ command to get a list of valid VM sized for your location 
            # Get-AzVMSize $location | Out-GridView
            $vmOSvhd = $osDisk.ICloudBlob.Uri
            $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $oldVmSize
            $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $vmName -VhdUri $vmOSVhd -CreateOption Attach -Windows # or -Linux
            $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

            Write-Output "$(get-date) - Creating vm $vmName in $location. Please wait 3 min."
            $NewVm = New-AzVM -VM $vmConfig -Location $location -ResourceGroupName $rg

            Write-Output "$(get-date) - Converting $vmName to managed Disk. Please wait."
            Stop-AzVM -ResourceGroupName $rg -Name $vmName -Force -Confirm:$false
            ConvertTo-AzVMManagedDisk -ResourceGroupName $rg -VMName $vmName
            Start-AzVm -ResourceGroupName $rg -Name $vmName -Confirm:$false

            # create managed disk from VHD if it doens't exist already
            $osDiskName = $vmName + "_" + $location + "_osdisk"
            Write-output "$(Get-Date) - Attaching dataDisks if any"
            
            $datablobfilter = $vmName + "_Data*"
            $dataDisks = Get-AzStorageBlob -Container 'snaps' -Context $sacontext -Blob $datablobfilter 
            foreach ($dataDisk in $dataDisks) {
                Write-Output "$(Get-Date) - Found $vmName's Data Disk $($dataDisk.name)"

                $dataDiskName = $vmName + "_" + $location + $dataDisk.name.Substring($dataDisk.name.IndexOf('_Data'), 6 ); 
                
                $lun = $dataDiskname.Substring(($dataDiskname.length - 1), 1 )
                Write-output "$(Get-Date) - Creating $vmName's Data Disk $dataDiskName"
        
                $DataVhdURL = $dataDisk.ICloudBlob.Uri;
                $DiskSizeGB = [int]($dataDisk.length / 1073741824)
                $diskConfig = New-AzDiskConfig -SkuName 'Standard_LRS' -Location $location -CreateOption Import -SourceUri $DataVhdURL -DiskSizeGB $DiskSizeGB
                $diskConfig = New-AzDisk -Disk $diskConfig -ResourceGroupName $rg -DiskName $dataDiskName 

                $disk = Get-AzDisk -ResourceGroupName $rgName -DiskName $dataDiskName 
                $vm   = Get-AzVM -Name $vmName -ResourceGroupName $rg
                $vm   = Add-AzVMDataDisk -CreateOption Attach -Lun $lun -VM $vm -ManagedDiskId $disk.Id

                Write-output "$(Get-Date) - Adding $vmName's $DiskSizeGB GB Data Disk $dataDiskName"
                Update-AzVM -VM $vm -ResourceGroupName $rg
            }
        }
    }

}
    

############################################################
# Main
#    To get a list of valid locations use the following command
#    Get-AzLocation |Format-Table
############################################################

$subid      = '444fcdb5-d696-4caf-9af2-8f2269152ed5' # $sub = 'HB-MAIN01-PROD'
$rg         = 'HBLLP-Azure-Extranet';
$from_location = 'centralus';
$to_rg      = 'unc_prod_extranet_rg';
$to_location = 'northcentralus';


# login if needed
$azaccount = Get-AzContext;
If ($azaccount.Subscription.Id -ne $subid) { Connect-AzAccount -Subscription $subid; }

<#
# set location for snaps to resource group location

# this assumes VMs are in same location as resource group location
$rgobj       = Get-AzResourceGroup -name $rg
$from_location = (Get-AzResourceGroup -name $rg).Location
$from_location = 'soutcentralus'

Write-Output ""
Write-Output "                         Welcome to Move-VMs"
Write-Output "*********************************************************************"
if ($from_location -eq $to_location) {write-output "Error. Nothing to do. from_location is the same as to_location. exiting."; exit 1}

Get-VMs -rg $rg
Write-Output ""
$answer = Read-Host -Prompt "OK to move the listed VMs in $from_location to $to_location ?"
if ($answer.ToLower() -eq "n" ) {write-output "exiting"; exit 1}
if ($answer.ToLower() -eq "no") {write-output "exiting"; exit 1}

# SNAP DISKS
Write-Output "$(get-date) - Calling InvokeSnapshotVMs on rg $rg for VMs in region $from_location"
Invoke-SnapshotVMs -rg $rg -location $from_location

# COPY DISKS
Write-Output "$(get-date) - Calling Copy-Snaps -rg $rg -from $from_location -to $to_location"
Copy-Snaps -rg $rg -from $from_location -to $to_location

<#temp code 
$azaccount  = Get-AzContext;
if ($to_location.length -lt 16 ) 
     {$storageAccountName = "snap" + $to_location + $azaccount.Subscription.Id.Substring(0,4)}
else {$storageAccountName = "snap" + $to_location.Substring(0,16) + $azaccount.Subscription.Id.Substring(0,4)}
#>

<# CREATE VMS
Write-Output "$(get-date) - Calling Create-VMs on rg $rg for VHDs in $storageAccountName in region $to_location"
Create-VMs -rg $rg -storageAccountName $storageAccountName

write-output " "
write-output "Well that was a lot of work. Enjoy the new home for the VMs."
write-output " "

Exit 1
#>