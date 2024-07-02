# User Variables
$ariaserver = "Aria automation server"
$password = "Aria automation password" | ConvertTo-SecureString -AsPlainText -Force
$user = "Aria automation user"
$owner = "The owner of the VM"
$ownerType = "AD_GROUP"
$Projectname = "VMs project name"
$csvPath = "Path of the file VMs-onbord.csv"
##############################################################################################################################################
# Import VMs from CSV file
$VMs = Import-Csv -Path $csvPath -UseCulture

# Connect to vRA Server
$request = Connect-vRAServer -Server $ariaserver -Username $user -Password $password
$accessToken = "Bearer " + $request.Token

# API Endpoint and Request Configuration
$uri = "https://"+$ariaserver+"/relocation/api/wo/quick/onboard-resources"
$method = "POST"
$header = @{
    "Accept"        = "application/json"
    "Content-Type"  = "application/json"
    "Authorization" = $accessToken
}

# Get vRA Project ID
$Project = Get-vRAProject -Name $Projectname
$Projectid = $Project.id

# Process VMs
foreach ($vm in $VMs) {
    $vRAVM = Get-vRAMachine -Name $vm.name
    $IDVM = $vRAVM.ID
    # Build the request body
    $Body = @{
        projectId = $Projectid
        deployments = @(
            @{
                resources = @(
                    @{
                        link = "/resources/compute/$IDVM"
                        name = $vRAVM.Name
                        type = "Cloud.vSphere.Machine"
                    }
                )
                name = $vRAVM.Name
                owner = $owner
                ownerType = $ownerType
            }

        )

    }
    # Convert the object to JSON
    $Body = $Body | ConvertTo-Json -Depth 4

    # Invoke REST API for each VM
    try {
        Invoke-RestMethod -Uri $uri -Method $method -Headers $header -Body $Body
        Write-Output "Successfully onboarded VM: $($vm.name)"
    } catch {
        Write-Error "Failed to onboard VM: $($vm.name). Error: $_"
    }
}
############################################################################################################################################## 
