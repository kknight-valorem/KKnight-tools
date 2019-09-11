# Set variables
    $resourceGroup = "unc_prod_extranet_rg"
    $vmName = "MSASP16WEB01"
    $newAvailSetName = "unc_prod_extranet_web_availset"

# Get the details of the VM to be moved to the Availability Set
    $originalVM = Get-AzVM `
	   -ResourceGroupName $resourceGroup `
	   -Name $vmName

# Create new availability set if it does not exist
    $availSet = Get-AzAvailabilitySet `
	   -ResourceGroupName $resourceGroup `
	   -Name $newAvailSetName `
	   -ErrorAction Ignore
    if (-Not $availSet) {
    $availSet = New-AzAvailabilitySet `
	   -Location $originalVM.Location `
	   -Name $newAvailSetName `
	   -ResourceGroupName $resourceGroup `
	   -PlatformFaultDomainCount 2 `
	   -PlatformUpdateDomainCount 2 `
	   -Sku Aligned
    }
    
# Remove the original VM
    Remove-AzVM -ResourceGroupName $resourceGroup -Name $vmName    

# Create the basic configuration for the replacement VM
    $newVM = New-AzVMConfig `
	   -VMName $originalVM.Name `
	   -VMSize $originalVM.HardwareProfile.VmSize `
	   -AvailabilitySetId $availSet.Id
  
    Set-AzVMOSDisk `
	   -VM $newVM -CreateOption Attach `
	   -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
	   -Name $originalVM.StorageProfile.OsDisk.Name `
	   -Windows

# Add Data Disks
    foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
    Add-AzVMDataDisk -VM $newVM `
	   -Name $disk.Name `
	   -ManagedDiskId $disk.ManagedDisk.Id `
	   -Caching $disk.Caching `
	   -Lun $disk.Lun `
	   -DiskSizeInGB $disk.DiskSizeGB `
	   -CreateOption Attach
    }
    
# Add NIC(s) and keep the same NIC as primary
	foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	
	if ($nic.Primary -eq "True")
		{
    		Add-AzVMNetworkInterface `
       		-VM $newVM `
       		-Id $nic.Id -Primary
       		}
       	else
       		{
       		  Add-AzVMNetworkInterface `
      		  -VM $newVM `
      	 	  -Id $nic.Id 
                }
  	}

# Recreate the VM
    New-AzVM `
	   -ResourceGroupName $resourceGroup `
	   -Location $originalVM.Location `
       -VM $newVM `
       -DisableBginfoExtension
# SIG # Begin signature block
# MIIPxwYJKoZIhvcNAQcCoIIPuDCCD7QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6tr1XUF6YXIq3xqIKpVSPvIO
# 3xOggg0OMIIFizCCBHOgAwIBAgITcQAGYCsU+SRMw/tSbgAAAAZgKzANBgkqhkiG
# 9w0BAQsFADBqMRQwEgYKCZImiZPyLGQBGRYEZmlybTETMBEGCgmSJomT8ixkARkW
# A2xhdzE9MDsGA1UEAxM0SHVzY2ggQmxhY2t3ZWxsIExMUCBJc3N1aW5nIENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAwMTAeFw0xOTA4MDcxODU5NTRaFw0yMjA4MDYxODU5
# NTRaMFAxGjAYBgNVBAMTEUVkZGxlc3RvbiwgU3R1YXJ0MTIwMAYJKoZIhvcNAQkB
# FiNTdHVhcnQuRWRkbGVzdG9uQGh1c2NoYmxhY2t3ZWxsLmNvbTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAMdK7zlDhDlm7kyduvR8BmNeuOH0G1+/+7w6
# DQOcoZEXu8ktC5qn9zZviAuqa6yp+m21LiRez4jEfhu0bhfw5YJRP1lQNtFjxe8d
# 1gBZ0yghj6NIl5R3UCJ+FLdOblriJc/tV2eIyPQEY3GLppx0EloQ6LSv0KDnTXHF
# IzOV8PnzSONju/rVUO8dTITCN9I07xt6FIfH0rXledf84zNB/9TDQjPuSY1SUmlo
# 9YVvDUq4UzaxTrCItrJozWLkXJwrTxgTYBveIsgqX1zx/q0EdWSE/FMIXwopohAl
# G4U37rm9A+WYfxOFM0dcEPrSIF1U9ubLdzS7OaCwYCys2ivs4rkCAwEAAaOCAkIw
# ggI+MD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCITjl2qHq/wzg4mPLIah6DqG
# z6sVT4XF8SyFtMNiAgFkAgEjMB0GA1UdJQQWMBQGCCsGAQUFBwMDBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCBsAwJwYJKwYBBAGCNxUKBBowGDAKBggrBgEFBQcDAzAK
# BggrBgEFBQcDCDAdBgNVHQ4EFgQUMgCuvUE4FKWRmzzNcqMphmI14LwwHwYDVR0j
# BBgwFoAUSVbJtMkhwQWj9LU4esfuc4DRSi4wfgYDVR0fBHcwdTBzoHGgb4ZtaHR0
# cDovL3BraS5odXNjaGJsYWNrd2VsbC5jb20vY2VydGVucm9sbC9IdXNjaCUyMEJs
# YWNrd2VsbCUyMExMUCUyMElzc3VpbmclMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0
# eSUyMDAxLmNybDCBpAYIKwYBBQUHAQEEgZcwgZQwgZEGCCsGAQUFBzAChoGEaHR0
# cDovL3BraS5odXNjaGJsYWNrd2VsbC5jb20vY2VydGVucm9sbC9LQ1BFTlRJU1NV
# RUNBLmxhdy5maXJtX0h1c2NoJTIwQmxhY2t3ZWxsJTIwTExQJTIwSXNzdWluZyUy
# MENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMDEuY3J0MD4GA1UdEQQ3MDWgMwYK
# KwYBBAGCNxQCA6AlDCNTdHVhcnQuRWRkbGVzdG9uQGh1c2NoYmxhY2t3ZWxsLmNv
# bTANBgkqhkiG9w0BAQsFAAOCAQEAS9BVLVRf/v2PhrGjIpjEhCgNsLYCvx1n+vuu
# DEwDHei244BVCTuJ+hsmHjSAn7gyMOVFRO11WR3wdiDEiVtGPGXUfgoTcMNh5+y1
# pvn8l7d0VC2LGEhAYeL8+FiR/02TsJbunCSCjqqwrXZr45x7T59ryPjGXvSbGsW7
# 5YnrbqRD5v9+pifFPAqn0HxaNwnhua37tT2Q6w2MM14soQi9QZUH86Jr34Yls3bW
# zn/TLQHddm8BSv61sktI610kGZcBeGXmrDaLwmN2PFeCqUfupLH+kR8GatHQSOSt
# WM7H2DcJP3+KCltFb/KLqqUmwsO+JY0CIse9tpDGrGellrRvbTCCB3swggVjoAMC
# AQICEx4AAAACMjbo8VDcudUAAAAAAAIwDQYJKoZIhvcNAQELBQAwOTE3MDUGA1UE
# AxMuSHVzY2ggQmxhY2t3ZWxsIExMUCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eTAeFw0xMzEwMzEwOTQ1MjZaFw0yMzEwMzEwOTU1MjZaMGoxFDASBgoJkiaJk/Is
# ZAEZFgRmaXJtMRMwEQYKCZImiZPyLGQBGRYDbGF3MT0wOwYDVQQDEzRIdXNjaCBC
# bGFja3dlbGwgTExQIElzc3VpbmcgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDAxMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwDYy1o3XblJyfWAD0NcG/R2t
# AbU9rAoVUJArgEWRLisWJjkLZ3y8Jdnj1ze8i4d0QytWfdNca4EaNI6znDzrD5N3
# uhfwu5Yi9g/IZhST/qApUx0AaYbup71MuZ8sBlFmuB661PzKcZuJfIQDRLRAmer/
# 7L2W2EQ2AU24K3ZrRT4FTMvbr2SN2yOmR6wf0c1Pe8LdIxVWc48ezo88zszfvJvw
# HmMabjrgdEGlgtE4NWGGpTaYVdONRAtUIXjwTur8Myr9cecseNbbWNYlaT80yFnt
# zRyqb9jCsh4CDukdDoIazlqI0UO+I2DNnK+Nxo/AnZ0lK3V128bmHFSq9Teu3wID
# AQABo4IDSTCCA0UwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFElWybTJIcEF
# o/S1OHrH7nOA0UouMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFGg9ZW2KiX2dn5yUXzyk
# dCHBQVhLMIIBSgYDVR0fBIIBQTCCAT0wggE5oIIBNaCCATGGZWh0dHA6Ly9wa2ku
# aHVzY2hibGFja3dlbGwuY29tL2NlcnRlbnJvbGwvSHVzY2glMjBCbGFja3dlbGwl
# MjBMTFAlMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3JpdHkuY3JshoHHbGRh
# cDovLy9DTj1IdXNjaCUyMEJsYWNrd2VsbCUyMExMUCUyMFJvb3QlMjBDZXJ0aWZp
# Y2F0ZSUyMEF1dGhvcml0eSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1sYXcsREM9ZmlybT9j
# QUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhv
# cml0eTCCAWgGCCsGAQUFBwEBBIIBWjCCAVYwfQYIKwYBBQUHMAKGcWh0dHA6Ly9w
# a2kuaHVzY2hibGFja3dlbGwuY29tL2NlcnRlbnJvbGwvS0NQU0FST09UQ0FfSHVz
# Y2glMjBCbGFja3dlbGwlMjBMTFAlMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRo
# b3JpdHkuY3J0MIHUBggrBgEFBQcwAoaBx2xkYXA6Ly8vQ049SHVzY2glMjBCbGFj
# a3dlbGwlMjBMTFAlMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3JpdHksQ049
# QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNv
# bmZpZ3VyYXRpb24sREM9bGF3LERDPWZpcm0/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29i
# amVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQAD
# ggIBAJFDTOUCC5163RpTNIMz+AAGbqsuvAMNmpLoxZikg0doQORV+FZ4JH+t/O1K
# SmOdZ9xOH3gQpFnLqiTtrpQQyL5K2O5kNllz7Wcq84AnQw3aTSHHG89hE07gDCps
# X6VUoCm6DJZMWjLD/bfsRfb1zWG5zHg+DFBU4MBdPE5SeDNNSQQZfdnCbzGxpaXc
# kapkf2omkVihqAMmyVt9Y3cNIAhDB3oXsJuhUpbtMNm2pSgFolJyL/q2tLs4phF5
# xcypvCsUlwUsU8HUUVid5rUFccymCaO1qyx6ObXLewPYDMnO1LpLsAonSp+HsdG9
# tAHTw4iFANHPzUZzU6H6g+z06mmZnJFdSG3fxzTesA3VpaL+lRgsZiDTE2u3YKUX
# NqmdJC/3eU+K5Mjz92YKjz/wwNrl1hUjVlc0cPLIiz35roMT5AQJzkDBB+tpZu9s
# vU7j5Yf/udWR5i85u1MY/v6u7iby5shdB4c59iy2+zjUZTW7NiLH2sun5RlK58YH
# oUK9jMiFH8tpLgkekvgk1AkgyYyuTy0XsdO+eSdC0ydLACm2dT9Kx5BePq2ZWY3H
# SoL88meeGU/t2Ld/BkWB2+cSLloZM97UhVf61nASOXRb0WywEC3AaxxMQcftesym
# zcz/PHPn/8lMeoY3r8PAoeNCB/pYYMNoJ65nxz5+WoRwPVDjMYICIzCCAh8CAQEw
# gYEwajEUMBIGCgmSJomT8ixkARkWBGZpcm0xEzARBgoJkiaJk/IsZAEZFgNsYXcx
# PTA7BgNVBAMTNEh1c2NoIEJsYWNrd2VsbCBMTFAgSXNzdWluZyBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMDECE3EABmArFPkkTMP7Um4AAAAGYCswCQYFKw4DAhoFAKB4
# MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkE
# MRYEFNmjBtkXd5Z/1zpN16hDZ2+kkGtyMA0GCSqGSIb3DQEBAQUABIIBAMUM2JjM
# zVF78BoMo+hzG7jjwbqU3mPCFeumrRk1ewyMY5KsDj+0nmsVSIxQXODwzda5/D8h
# YNzNHWIFgKWCCd4Ao5TljBF2LJesnd4DcHWdn9g2GRDa/YESLTnMvlUwLUcx2C/N
# t2yU/WpJm5UwP3qwvmndkxSZSYnooD5zpt7/Q4e0o58vz9LFfQoRZx8o26qBoKRm
# A4RlHLhnAanFnb+SbvL08wdRwBUxhOdvx3+fwRY8JNrzy7V0X980teo/g/W7raC8
# vRDoenepoAIOVRASFR3TAMrCpJAHG9bkJQkGvWT0ehuThHADa1DQ2HDLjXrxDpGQ
# 7Mrrpa8UMNw38uk=
# SIG # End signature block
