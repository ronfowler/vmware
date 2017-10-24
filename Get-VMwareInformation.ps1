#Requires -Version 3.0


#You need to download the PowerCLI Module from VMware

#Add the PSSnapin from PowerCLI
#Add-PSSnapin VMware.VimAutomation.Core

#Connect to either a host or vSphere
#Connect-VIServer "YOUR HOST OR vSPHERE SERVER"


<#
.SYNOPSIS
Returns CPU, Memory and Network information about a host, this is mainly for reporting.

.PARAMETER VMHost
(OPTIONAL) Host from pipeline value Get-VMHost | Get-VMHostInfo would get all host information based on what you connected to when you issued Connect-VIServer, if it was a vSphere instance it would get all hosts

.PARAMETER name
(OPTIONAL) Host name which can come from the pipeline

.LINK
https://github.com/ronfowler

#>
function Get-VMHostInfo {
    Param(
        [parameter(Mandatory=$false, ValueFromPipline)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
        $VMHost,

        [parameter(Mandatory=$false)]
        [string]
        $Name
    
    )


    Process {
    
        if (-not($VMHost -or $Name)) {
            throw [System.ArgumentNullException] "You must pass a Host to this method from Get-VMHost or you must specify -name NAMEOFYOURHOST"
        }

        if ($Name) {
            $vmhost = Get-VMHost -Name $name            
        }
        
        
        $Details = [PSCustomObject]@{
            "VMHostName" = $vmhost.Name
            "VMHostVersion" = $vmhost.Version
            "VMHostBuild" = $vmhost.Build
            "VMHostManufacturer" = $vmhost.Manufacturer
            "VMHostModel" = $vmhost.Model
            "VMHostNumCpu" = $vmhost.NumCpu
            "VMHostCpuTotalMhz" = $vmhost.CpuTotalMhz
            "VMHostCpuUsageMhz" = $vmhost.CpuUsageMhz
            "VMHostMemoryTotalGB" = $vmhost.MemoryTotalGB
            "VMHostMemoryUsageGB" = $vmhost.MemoryUsageGB
            "VMHostProcessorType" = $vmhost.ProcessorType
            "VMHostLicenseKey" = $vmhost.LicenseKey  
            "VMHostVirtualNicName" = $null
            "VMHostVirtualNicMac" = $null                       
            "VMHostVirtualNicIP" = $null
            "VMHostVirtualNicMask" = $null
            "VMHostVirtualNicVmotion" = $null
            "VMHostVirtualNicMGMTTraffic" = $null
            "VMHostVirtualNicPortGroupName" = $null
        }

        foreach($nic in $vmhost.NetworkInfo.VirtualNic) {
            $Details.VMHostVirtualNicName = $nic.Name
            $Details.VMHostVirtualNicMac = $nic.Mac
            $Details.VMHostVirtualNicIP = $nic.IP
            $Details.VMHostVirtualNicMask = $nic.SubnetMask
            $Details.VMHostVirtualNicVmotion = $nic.VMotionEnabled
            $Details.VMHostVirtualNicMGMTTraffic = $nic.ManagementTrafficEnabled
            $Details.VMHostVirtualNicPortGroupName = $nic.PortGroupName

            $Details
        }                   
    }        
}

<#
.SYNOPSIS
This will list all the disks attached to the VM as well as calculate what the drive size should be for the C:\ based on 5 times the amount of allocated memory.

.PARAMETER VM
(OPTIONAL) This requires input from cmdlets such as Get-VM as it is strongly typed to VirtualMachineImpl

.PARAMETER Name
(OPTIONAL) Name of VM

.LINK
https://github.com/ronfowler
#>
function Get-VMDiskInfo {
    Param(
        [parameter(Mandatory=$false, ValueFromPipeline)]  
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]
        $VM,

        [parameter(Mandatory=$false)]
        [string]
        $Name
    )




    Process {

        if (-not($VM -or $Name)) {
            throw [System.ArgumentNullException] "You must pass a VM to this method from Get-VM or you must specify -name NAMEOFYOURVM"
        }
     
        $guest = $null

        if ($VM){
            $guest = $VM.Guest                
        } else {
            $guest = Get-VM -Name $Name | Select guest
        }

        foreach($disk in $guest.Disks) {

            $Details = [PSCustomObject]@{
                "Hostname" = $guest.HostName
                "Server" = $guest.VmName                       
                "CPUs" = $vm.NumCPU
                "MemoryGB" = $vm.MemoryGB
                "OperatingSystem" = $guest.OSFullName
                "VMToolsVersion" = $guest.ToolsVersion
                "Notes" = $vm.Notes
                "Disk Path" = $disk.Path
                "Capacity(GB)" = ([math]::Round($disk.CapacityGB))
                "UsedSpace(GB)" = ([Math]::Round($disk.CapacityGB - $disk.FreeSpaceGB))
                "FreeSpace(GB)" = ([math]::Round($disk.FreeSpaceGB))
                "Percentage Free" = ([Math]::Round($disk.FreeSpaceGB / $disk.CapacityGB * 100))
                "Required Free" = ($vm.MemoryGB * 5)
                "IncreaseSpace" = $false
            }


            if ($Details.'Disk Path' -eq "C:\" -and  $Details.'FreeSpace(GB)' -lt $Details.'Required Free') {
                $Details.IncreaseSpace = $true
            }
            
            $Details
        } 
        
        
    }
   
}

<#
.SYNOPSIS
This will list all the network interfaces attached to the VM.

.PARAMETER VM
This requires input from cmdlets such as Get-VM as it is strongly typed to VirtualMachineImpl

.LINK
https://github.com/ronfowler
#>
function Get-VMNetworkInfo {
    Param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName, ValueFromPipeline)]  
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]
        $VM        
    )


    Process {

        $guest = $VM.Guest
        
        foreach($nic in $guest.Nics) {
            $Details = [PSCustomObject]@{
                "Hostname" = $guest.HostName
                "Server" = $guest.VmName                       
                "CPUs" = $vm.NumCPU
                "MemoryGB" = $vm.MemoryGB
                "OperatingSystem" = $guest.OSFullName
                "VMToolsVersion" = $guest.ToolsVersion
                "Notes" = $vm.Notes
                "Connected" = $nic.Connected
                "MacAddress" = $nic.Device.MacAddress
                "NetworkName" = $nic.Device.NetworkName
                "AdapterType" = $nic.Device.Type
                "IPAddress" = ""
            
            }    
            if ($guest.IPAddress) {
                if ($guest.IPAddress -is [array]) {
                    $Details.IPAddress = [string]::Join(",",$guest.IPAddress)
                }
            } else {
                    $Detail.IPAddress = $guest.IPAddress
            }

            $Details            
        }

    }


}

<#
.SYNOPSIS
This will list all the disks attached to all VM's that are currently powered on as well as calculate what the drive size should be for the C:\ based on 5 times the amount of allocated memory
#>
function Get-VMDiskandNicInfo {
    Param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName, ValueFromPipeline)]  
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]
        $VM
    )


    Process {
        $guest = $VM.Guest                

        foreach($disk in $guest.Disks) {

            $Details = [PSCustomObject]@{
                "VMHostName" = $VM.VMHost.Name
                "VMHostManufacturer" = $VM.VMHost.Manufacturer
                "VMHostModel" = $VM.VMHost.Model
                "VMHostNumCpu" = $VM.VMHost.NumCpu
                "VMHostCpuTotalMhz" = $VM.VMHost.CpuTotalMhz
                "VMHostCpuUsageMhz" = $Vm.VMHost.CpuUsageMhz
                "VMHostMemoryTotalGB" = $VM.VMHost.MemoryTotalGB
                "VMHostMemoryUsageGB" = $Vm.VMHost.MemoryUsageGB
                "VMHostProcessorType" = $vm.VMHost.ProcessorType
                "VMHostLicenseKey" = $VM.VMHost.LicenseKey
                "Dnsname" = $guest.HostName
                "Server" = $guest.VmName                       
                "CPUs" = $vm.NumCPU
                "MemoryGB" = $vm.MemoryGB
                "OperatingSystem" = $guest.OSFullName
                "VMToolsVersion" = $guest.ToolsVersion
                "Notes" = $vm.Notes
                "Disk Path" = $disk.Path
                "Capacity(GB)" = ([math]::Round($disk.CapacityGB))
                "UsedSpace(GB)" = ([Math]::Round($disk.CapacityGB - $disk.FreeSpaceGB))
                "FreeSpace(GB)" = ([math]::Round($disk.FreeSpaceGB))
                "Percentage Free" = ([Math]::Round($disk.FreeSpaceGB / $disk.CapacityGB * 100))
                "Required Free" = ($vm.MemoryGB * 5)
                "IncreaseSpace" = $false
                "Connected" = $null
                "MacAddress" = $null
                "NetworkName" = $null
                "AdapterType" = $null
                "IPAddress" = $null
            }


            if ($Details.'Disk Path' -eq "C:\" -and  $Details.'FreeSpace(GB)' -lt $Details.'Required Free') {
                $Details.IncreaseSpace = $true
            }

            foreach($nic in $guest.Nics) {
                $Details.Connected = $nic.Connected
                $Details.MacAddress = $nic.Device.MacAddress
                $Details.NetworkName = $nic.Device.NetworkName
                $Details.AdapterType = $nic.Device.Type   
                
                if ($guest.IPAddress) {
                    if ($guest.IPAddress -is [array]) {
                        $Details.IPAddress = [string]::Join(",",$guest.IPAddress)
                    }
                } else {
                    $Detail.IPAddress
                }                                         

                $Details
            }
            
            
        } 
        
        
    }

}


<#
.SYNOPSIS
Checks to see if the VM specified is poweredon and the tools need updated on the VM specified.  It will also dump the result of the action to a file and to the screen.

.PARAMETER name
This is the exact name of the VM

.PARAMETER path
This is the path to the log file including the filename.extension

.EXAMPLE
Update-VMTools -name MYTESTSERVER -log c:\users\someuser\update-vmtools.log

.LINK
https://github.com/ronfowler

#>
function Update-VMTools {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName)]   
        [string]
        $name,

        [parameter(Mandatory=$true)]
        [string]
        $log

    )
    


    Process {

        
        $vm = Get-VM -Name $name | where { $_.PowerState -ne "poweredoff" }
        

        if ($vm) {
            
            $view = $vm | Get-View | where { $_.Guest.ToolsVersionStatus -eq "guestToolsNeedUpgrade" }

            if ($view) {
                try {
                    Update-Tools -NoReboot -VM $view.name    
                    Write-Log -Path $log -Message "VM $($name) Tools updated successfully"
                } catch {
                    Write-Log -Path $log -Message "VM $($name) threw an exception: $($_.Exception.Message)" -IsError
                }
                
            } else {
                Write-Log -Path $log -Message "VM $($name) Tools are already up to date." -IsError
            }
        } else {
            Write-Log -Path $log -Message "VM $($name) either does not exist or is not powered on." -IsError
        }
        

    }
}


<#
.SYNOPSIS
Records information to a file and also displays text formatted to the screen.  This will save it tab delimited and prefixes all entries with the date/time.  There are three columns:  datetime,message,error

.PARAMETER Path
Full path to the file which will be the log

.PARAMETER Message
information you wish to record in the log

.PARAMETER IsError
No parameter = $false otherwise pass $true

.EXAMPLE
LogWrite "This is a test" "0"

Writes current time {tab} This is a test {tab} 0 to a file and to the screen.
#>
function Write-Log {
    Param (
    [parameter(Mandatory=$true)]
    [string]
    $Path,
    
    [parameter(Mandatory=$true)]
    [string]
    $Message,
    
    [parameter(Mandatory=$false)]
    [switch]
    $IsError

    )

    $TimeDate = Get-Date -Format "yyyy-MM-dd-HH:mm:ss"
    
    $Val = [string]::join("`t",$TimeDate.ToString(), $Message, $IsError).ToString()
    
    Add-Content -Path $Path -Value $Val -ErrorAction Stop
    
    if ($IsError -eq $false ) {
        Write-Host $Message -ForegroundColor Green
    } else {
        Write-Host $Message -ForegroundColor DarkYellow
    }
}






#Get all Powered On VM's
#$VMS = Get-VM | Where-Object { $_.PowerState -ne "PoweredOff" }

#Get lots of information on VM's
#NOTE: The CSV will have a row for each drive attached to the VM, so if you're looking for information just on C:\ you can filter it in Excel
#$VMS | Get-VMDiskandNicInfo | Export-Csv -NoTypeInformation -log "\\Path\To\File.csv"

#Pass the VM's to the Get-VMDiskInfo function for grabbing specific properties and send it to a CSV with the current date time stamp.
#$VMS | Get-VMDiskInfo | Export-Csv -NoTypeInformation -log "\\Path\To\File.csv"

#Pass the VM's to the Get-VMNetworkInfo function for grabbing specific properties and send it to a CSV with the current date time stamp.
#$VMS | Get-VMNetworkInfo | Export-Csv -NoTypeInformation -log "\\Path\To\File.csv"

