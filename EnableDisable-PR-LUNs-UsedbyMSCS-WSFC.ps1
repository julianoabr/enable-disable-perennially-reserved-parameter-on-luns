#Requires -RunAsAdministrator
#Requires -Version 4.0

<#
    .Synopsis
    Script para gerar e corrigir o parâmetro perennialy reserved nas LUNS reservadas para MCSC
    .Version
    0.4
    .Author
    Juliano Alves de Brito Ribeiro
    .Notes
    Preencher com as LUNs o arquivo naa_mscs_host_default.txt
    .Improvements
    Adicionado Menu para escolher Host ESXi
#>

Clear-Host

function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

Clear-Host

Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop

Write-Output "`n"
Write-Output "Select Vcenter Number that you want to connect"
Write-Output "`n"

#CREATE VCENTER LIST
$vcServers = @();
$vcServers = ("tbambev-vcsrv001a.la.interbrew.net","tbambev-vmlx0111.la.interbrew.net")

$workingLocationNum = ""
$tmpWorkingLocationNum = ""
$WorkingServer = ""
$i = 0

foreach ($vcServer in $vcServers){
	   
        $vcServerValue = $vcServer
	    
        Write-Output "            [$i].- $vcServerValue ";	
	    $i++	
        }#end foreach	
        Write-Output "            [$i].- Exit this script ";

        while(!(isNumeric($tmpWorkingLocationNum)) ){
	        $tmpWorkingLocationNum = Read-Host "Type Vcenter Number that you want to connect"
        }#end of while

            $workingLocationNum = ($tmpWorkingLocationNum / 1)

        if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	        $WorkingServer = $vcServers[$WorkingLocationNum]
        }
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else

$port = '443'

#Connect to Vcenter
Connect-VIServer -Server $WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue


#Set-PowerCLIConfiguration -WebOperationTimeoutSeconds -1

$outputPath = "$env:systemdrive\SCRIPTS\BOX\Process\Vmware\Host\PerenniallyReserved\Reports"

Set-Location -Path "$env:systemdrive\SCRIPTS\BOX\Process\Vmware\Host\PerenniallyReserved"

$dataAtual = (Get-date -Format dd-MM-yyyy_HHmm)

$shortDate = (Get-date -Format ddMMyyyy)

Write-Output "`n"
Write-Output "Select Cluster that you want to Verify"
Write-Output "`n"

#CREATE CLUSTER LIST
$VCClusterList = (get-cluster  | Select-Object -ExpandProperty Name| Sort-Object)

$tmpWorkingClusterNum = ""
$WorkingCluster = ""
$i = 0

#CREATE CLUSTER MENU LIST
foreach ($VCCluster in $VCClusterList){
	   
        $VCClusterValue = $VCCluster
	    
        Write-Output "            [$i].- $VCClusterValue ";	
	    $i++	
        }#end foreach	
        Write-Output "            [$i].- Exit this script ";

        while(!(isNumeric($tmpWorkingClusterNum)) ){
	        $tmpWorkingClusterNum = Read-Host "Type the Vcenter Cluster Number that you want to Rescan/Refresh"
        }#end of while

            $workingClusterNum = ($tmpWorkingClusterNum / 1)

        if(($workingClusterNum -ge 0) -and ($workingClusterNum -le ($i-1))  ){
	        $WorkingCluster = $vcClusterList[$workingClusterNum]
        }
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else

#DEFINE CLUSTER TO VIEW
[string]$Cluster = $WorkingCluster


$locationList = @();
$workingLocationNum = ""
$tmpWorkingLocationNum = ""
$WorkingLocation = ""
$i = 0


Write-Output "`n"
Write-Output "Select ESXI Host Number that you want to verify"
Write-Output "`n"


#GENERATE HOST LIST
$locationList = Get-Cluster -Name $Cluster | Get-VMHost | Select-Object -ExpandProperty Name | Sort-Object

foreach ($location in $locationList){
	  $LocationHasValue = $location
	     Write-Output "            [$i].- $LocationHasValue ";	
	     $i++	
        }#end foreach	
        Write-Output "            [$i].- Exit this script ";

        while(!(isNumeric($tmpWorkingLocationNum)) ){
	        $tmpWorkingLocationNum = Read-Host "Type The Number of ESXi Host that you want to verify Perennially Reserved Parameter"
            
        }#end of while

            $workingLocationNum = ($tmpWorkingLocationNum / 1)

        if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))){
	        $WorkingLocation = $locationList[$WorkingLocationNum]
        }
        else{
            
            Write-Host "Exit selected, or Invalid choice number.  Script halted" -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else


$vmHost = $WorkingLocation

$myesxcli= get-esxcli -VMHost $vmHost

if (Test-Path "$outputPath\ReportAllLUNs-$shortDate-$vmHost-PR.txt"){
    
    Write-Output "File with all LUNS presented to Host ESXi: $vmHost already exists for the date: $shortDate"

}#end of if
else{

    Write-Output "File with all LUNS presented to Host ESXi: $vmHost does not exists for the date: $shortDate"
    
    Write-Output "Generating..."
    
    $myesxcli.storage.core.device.list() | Out-File -FilePath "$outputPath\ReportAllLUNs-$shortDate-$vmHost-PR.txt" -Append 
}

$naaList = @()
$naaList = (Get-Content -Path ".\naa_mscs_host_default.txt")

$naaList2 = @()
$naaList2 = (Get-Content -Path ".\naa_mscs_host_correct.txt")

Do {
    Write-Output "

----------MENU CORRECT Perennially Reserved----------

You are connected to Vcenter: $workingServer
You selected the Cluster: $Cluster
You selected the ESXi Host: $vmHost

1 = Generate Report Perennially Reserved Before
2 = Generate Report Perennially Reserved After
3 = Enable Perennially Reserved
4 = Disable Perennially Reserved 
5 = Exit

--------------------------"

$choice1 = Read-host -prompt "Select an Option and Press Enter"
} until ($choice1 -eq "1" -or $choice1 -eq "2" -or $choice1 -eq "3" -or $choice1 -eq "4" -or $choice1 -eq "5")

Switch ($choice1) {
"1" {
 
    Write-Host "GENERATING REPORT BEFORE CHANGES" -ForegroundColor Red -BackgroundColor White

    foreach($naa in $naaList){
        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naa}
        $myesxcli.storage.core.device.list($naa) | Select-Object -Property Device,IsOffline,IsPerenniallyReserved | export-csv -NoTypeInformation -Path "$outputPath\ReportBefore-$dataAtual-$vmHost-PR.csv" -Append
    }


}#end of 1
"2" {

  Write-Host "GENERATING REPORT AFTER CHANGES" -ForegroundColor Red -BackgroundColor White
    
    foreach($naa in $naaList){
        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naa}
        $myesxcli.storage.core.device.list($naa) | Select-Object -Property Device,IsOffline,IsPerenniallyReserved | export-csv -NoTypeInformation -Path "$outputPath\ReportAfter-$dataAtual-$vmHost-PR.csv" -Append
    }
        
        

}#end of 2
"3" {

  
            Write-Output "You Choose Enabled"

            do
            {
                
                 Write-host "Do you want to use list 1: (naa_mscs_host_default.txt) or list 2: (naa_mscs_host_correct.txt)" -ForegroundColor Yellow -BackgroundColor Black
                 
                 $ChoiceList = Read-Host "Press Number 1 or 2"
                 
                 if ($ChoiceList -eq 1){
                 
                    foreach($naa in $naaList){
                
                        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naa}
                
                        $deviceNAA = $device.Device
            
                        Write-Host "Set Perennially Reserverd to True to Device: $deviceNAA on host $vmHost" -BackgroundColor DarkBlue -ForegroundColor White
 
                        $myesxcli.storage.core.device.setconfig($false, $device.device, $true)

                        Start-Sleep -Milliseconds 30
                    }#END FOREACH
                 
                 
                 
                 }#END OF IF 1   
                 if ($ChoiceList -eq 2){
                 
                     foreach($naaC in $naaList2){
                
                        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naaC}
                
                        $deviceNAAC = $device.Device
            
                        Write-Host "Set Perennially Reserverd to True to Device: $deviceNAAC on host $vmHost" -BackgroundColor DarkBlue -ForegroundColor White
 
                        $myesxcli.storage.core.device.setconfig($false, $device.device, $true)

                        Start-Sleep -Milliseconds 30
                    }#END FOREACH
                 
                                  
                 
                 }#END OF IF 2
                  
                  
            }
            while ($ChoiceList -notmatch ('^(?:1\b|2\b)'))

  
}#end of 3
"4" {

            Write-Output "You Choose Disabled"
            

             do
            {
                
                 Write-host "Do you want to use list 1: (naa_mscs_host_default.txt) or list 2: (naa_mscs_host_correct.txt)" -ForegroundColor Yellow -BackgroundColor Black
                 
                 $ChoiceList = Read-Host "Press Number 1 or 2"
                 
                 if ($ChoiceList -eq 1){
                 
                    foreach($naa in $naaList){
                        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naa}
        
                        $deviceNAA = $device.Device
            
                        Write-Host "Set Perennially Reserverd to FALSE to Device: $deviceNAA on host $vmHost" -BackgroundColor DarkBlue -ForegroundColor White
        
                        $myesxcli.storage.core.device.setconfig($false, $device.device, $false)

                        Start-Sleep -Milliseconds 30
         }#END FOREACH
                 
                 
                 
                 }#END OF IF 1   
                 if ($ChoiceList -eq 2){
                 
                    foreach($naaC in $naaList2){
                        $device = $myesxcli.storage.core.device.list() | Where-Object {$_.Device -like $naaC}
        
                        $deviceNAAC = $device.Device
            
                        Write-Host "Set Perennially Reserverd to FALSE to Device: $deviceNAAC on host $vmHost" -BackgroundColor DarkBlue -ForegroundColor White
        
                        $myesxcli.storage.core.device.setconfig($false, $device.device, $false)

                        Start-Sleep -Milliseconds 30
                    }#END FOREACH
                 
                 }#END OF IF 2
                 
                  
            }
            while ($ChoiceList -notmatch ('^(?:1\b|2\b)'))

}#end of 4
"5" {
    

    Write-Output " "
    
    Write-Output "Exit of Menu Script..."
    
    Exit

}#end of 5

}#end of switch

Disconnect-VIServer -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
