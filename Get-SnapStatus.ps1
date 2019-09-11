function Get-SnapStatus {
    $subid      = '444fcdb5-d696-4caf-9af2-8f2269152ed5' # $sub = 'HB-MAIN01-PROD'
    $rg         = 'unc_prod_extranet_rg'
    $to_location = 'northcentralus';
    $storageAccountName = 'snapnorthcentralus444f';

    # Set the name of the storage account and the SKU name
    $location           = (Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $rg).Location
    $storageAccountKey  = Get-AzStorageAccountKey -ResourceGroupName $rg -Name $storageAccountName
    $sacontext          = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey[0].Value
    $osDisks            = Get-AzStorageBlob -Container 'snaps' -Context $sacontext -Blob *_OSnap_*

    foreach ($osDisk in $osDisks) { Get-AzureStorageBlobCopyState -Blob $osDisk -Container 'snap'-Context $sacontext     }
}

Get-AzureStorageBlobCopyState -blob MSASP16APP01_Data1_201908120716.vhd -Container 'snap'