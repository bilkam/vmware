# User variables
$VCUsername = "User name to your vCENTER and SDDC"
$Vcpassword = "Password to your vCENTER and SDCC"
$vcenterserver = "FQDN or IP of your vcenter"
$sddcmanager = "FQDN or IP of your SDDC"
$listVMs= "vCENTER0*"
# Step 0 : coonect to the vcenter server and sddc manager
Connect-VIServer -Server $vcenterserver -User $VCUsername -Password $Vcpassword  
Request-VCFToken -fqdn $sddcmanager -User $VCUsername -Password $Vcpassword
# Step 1: Get all VMs informations  
$VMs= Get-VM -Name $listVMs | Select-Object Name, VMHost    
 
# Step 2 : Retrieve the password of VMHosts associated with the VMs retrieved earlier
foreach ($VM in $VMs) {
    $vmHost = $VM.VMhost.name
    $password = Get-VCFCredential -resourceName $vmHost | Where-Object { $_.username -eq "root" } | Select-Object -ExpandProperty password
    [PSCustomObject]@{
        VMName  = $VM.Name
        VMHost   = $VM.VMhost.name
        Password = $password
    }
}

# Step 3 : Enable ssh service on all VMhost
foreach ($VM in $VMs) {
    $vmHost = $VM.VMhost.name
    Get-VMHost -name $vmHost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Start-VMHostService
 }
 
# Step 4 : Get all VMs informations
$vmInfoList=@()
foreach ($VM in $VMs) {
    $vmHost = $VM.VMhost.name
    # Establish an SSH session to the VMHost
    $session = New-SSHSession -ComputerName $vmHost -Credential (New-Object System.Management.Automation.PSCredential("root", (ConvertTo-SecureString $password -AsPlainText -Force)))
    if ($session) {
        Write-Host "Connected to $vmHost"
    # Get VM ID on the ESXI
        $command = "vim-cmd vmsvc/getallvms | grep " + $VM.Name
        $output= (Invoke-SSHCommand -SessionId $session.SessionId -Command $command).Output
        $vmId = ($output -split '\s+')[0]
        $vmInfoList += [PSCustomObject]@{
            VMName  = $VM.Name
            VMHost  = $vmHost
            VMId    = $vmId
            Password = $password
            Session = $session.SessionId
        }
    }else {
        Write-Host "Failed to connect to $vmHost"
    }
}
 
# Step 5: Power off all VMs
foreach ($vmInfo in $vmInfoList) {
    $command = "vim-cmd vmsvc/power.off $($vmInfo.VMId)"
    $result = (Invoke-SSHCommand -SessionId $vmInfo.Session -Command $command).Output
    Write-Host "Powering off VM $($vmInfo.VMName): $result"
}
 
# Step 6: Take snapshots of all VMs
foreach ($vmInfo in $vmInfoList) {
    $snapshotName = "$($vmInfo.VMName)_Offline_Snapshot_$(Get-Date -Format 'yyyyMMddHHmmss')"
    $command = "vim-cmd vmsvc/snapshot.create $($vmInfo.VMId) $snapshotName 'Snapshot created via script' 0 0"
    $result = (Invoke-SSHCommand -SessionId $vmInfo.Session -Command $command).Output
    Write-Host "Snapshot created for VM $($vmInfo.VMName): $result"
}
 
# Step 7: Power on all VMs
foreach ($vmInfo in $vmInfoList) {
    $command = "vim-cmd vmsvc/power.on $($vmInfo.VMId)"
    $result = (Invoke-SSHCommand -SessionId $vmInfo.Session -Command $command).Output
    Write-Host "Powering on VM $($vmInfo.VMName): $result"
}

# Step 8: Close SSH sessions
foreach ($vmInfo in $vmInfoList) {
    if ($vmInfo.Session) {
        Remove-SSHSession -SessionId $vmInfo.Session
        Write-Host "Closed SSH session for $($vmInfo.VMHost)"
    }
}
 
# Step 10: Wait until the vCenter server is accessible again on port 443
do {
    Write-Host "Waiting for vCenter server to become accessible on port 443..."
    Start-Sleep -Seconds 60
    $vCenterAccessible = Test-NetConnection -ComputerName $vcenterserver -Port 443 -InformationLevel Quiet
} while (-not $vCenterAccessible)
 
Write-Host "vCenter server is now accessible on port 443."
 
# Step 11: disable ssh on all vmhost
Connect-VIServer -Server $vcenterserver -User $VCUsername -Password $Vcpassword  
foreach ($VM in $VMs) {
    $vmHost = $VM.VMhost.name
    Get-VMHost -name $vmHost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Stop-VMHostService -Confirm:$false
 }
 
#Step 12: Disconnect from the vcenter server
Disconnect-VIServer -Server $vcenterserver   -Confirm:$false
#End of script
