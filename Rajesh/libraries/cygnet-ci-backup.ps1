<# 
::@title This backup powershell program is called from the cygnet-ci--main  batch file 
   and used to back web and service current deployed files.

::@author Rajesh Prajapati
::@date  21/01/2018
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$whatTodeploy,
    [Parameter(Mandatory = $True, Position = 2)]
    [string]$inipath
)

# @dev This Function used for read parameter from the config file.
Function Get-IniContent {  
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript( {(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]  
        [Parameter(ValueFromPipeline = $True, Mandatory = $True)]  
        [string]$FilePath
    )  
    Begin  
    {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
    Process {  
		
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
        $ini = @{}  
        switch -regex -file $FilePath {  
            "(.+?)\s*=\s*(.*)" # Key  
            {  
            $name, $value = $matches[1..2]  
            $ini[$name] = $value  
            }  
        }  
    Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
    Return $ini  
    }  
End  
{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
} 

# @dev Read the full or hotfix ini file based on the @iniPath param which consist of database,vm and release path locations. 
#$FileContent = Get-IniContent "E:\Phase _3_Test\phase3\ci-normal.ini"
$FileContent = Get-IniContent "$inipath"

# @dev read from ini file the setting values related to network from where the source is derived to release the latest files.
# @dev Get the AES key from the FileSystem
$key = (184,125,226,226,94,84,209,47,36,55,196,173,134,210,63,17,28,42,170,217,54,146,218,191,66,138,69,233,29,30,232,38)

# @dev decrypt the windows username and  password  to established network drive connection.
$network_win_password = ($FileContent["network_win_password"] -replace '"', '' | ConvertTo-SecureString -Key $key)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($network_win_password)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$network_win_user = ($FileContent["network_win_user"] -replace '"', '' | ConvertTo-SecureString -Key $key)
$network_win_password = ConvertTo-SecureString -AsPlainText -Force -String $PlainPassword
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($network_win_user)
$PlainUserName = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$currentdate = Get-Date -DisplayHint DateTime -Format dd.MM.yyyy

# @dev read from ini file the setting values related to vm where the current  files  is back up from vm machine relase source.
$vm_servername_db = $FileContent["vm_servername_db"] -replace '"', ''
$vm_servername_web = $FileContent["vm_servername_web"] -replace '"', ''
$vm_servername_app = $FileContent["vm_servername_app"] -replace '"', ''
$vm_web_backup = $FileContent["vm_web_backup"] -replace '"', ''
$vm_web_deploy = $FileContent["vm_web_deploy"] -replace '"', ''
$vm_service_backup = $FileContent["vm_service_backup"] -replace '"', ''
$vm_service_deploy = $FileContent["vm_service_deploy"] -replace '"', ''
$vm_deploy_mode = $FileContent["vm_deploy_mode"] -replace '"', '' 
$network_deployment_logs = $FileContent["network_deployment_logs"] -replace '"', '' 

$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $PlainUserName, $network_win_password


$logFile = $network_deployment_logs +"\cygnet_ci_backup_logs_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"

function writeLog($string, $color){
   if ($Color -eq $null) {$color = "white"}
   write-host $string -foregroundcolor $color
   $string | out-file -Filepath $logfile -append
   
}

# dev backup to remote machine
writeLog "[INFO]-BACKUP SESSION STARTING..."
write-host "[INFO]-BACKUP SESSION STARTING..."

foreach ($computer in $vm_servername_web) {

    if (test-Connection -Cn $computer -quiet) {

        if ($whatTodeploy -eq "Website") {
       		
            writeLog "[INFO]-BACKUP SESSION STARTING..."
            write-host "[INFO]-WEBSITE BACKUP STARTING..."

            $foldername = "Website"
				
            # dev This code will read value upto the network path.See below example
            # dev  value=\\192.192.5.13\e$\Backups.substring("\\".getindexnumberofstring,"$".getindexnumberofstring)
             # dev This is used for check Vmdeplymode=local\network.

            if ($vm_deploy_mode -eq "network") {

                  $map_vm_drivepath = $vm_web_backup.substring($vm_web_backup.indexof("\\"), $vm_web_backup.IndexOf("$") + 1)

                  $vm_web_backup = $vm_web_backup.substring($vm_web_backup.indexof("$") + 1)

            # dev The New-PSDrive cmdlet functions similar to the Subst command: it enables you to map a drive 
            # dev (in this case, of course, a Windows PowerShell drive letter) to a path. 
            # dev For example, this command creates a new Windows PowerShell drive (drive X) 
            # dev that’s mapped to the folder C:\Scripts: 
            # dev New-PSDrive -name X -psprovider FileSystem -root c:\scripts
            # dev The program will do map drive only when we are doing activities in network mode.
                     
             New-psdrive Y filesystem $map_vm_drivepath -Credential $credentials 

             $path = "Y:" + $vm_web_backup + "\" + $currentdate + "\" + $foldername
                        
          
             } else {    
              
             # dev This path working for local mode.
                                                  
             $path = $vm_web_backup + "\" + $currentdate + "\" + $foldername

            }

            # dev The folder already exist then that folder overwrite and if folder not exist then create new folder.
            #md $path used for create new folder on that's path.
            
            mkdir -Force -Path $path
				
            # dev to copy all the files we are append \* with vm_web_deploy param.
            $currentwebpath = $vm_web_deploy + "\*"

                                 
				
            # dev The Copy-Item cmdlet copies an item from one location to another location.
            Copy-Item -Force -Recurse $currentwebpath -Destination $path
			
            writeLog "[INFO]-WEBSITE BACKUP SUCCESSFULLY DONE..."	
            Write-output "[INFO]-WEBSITE BACKUP SUCCESSFULLY DONE..."
				
            # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
            # dev that were created by using the New-PSDrive cmdlet.
            # dev The program will do map drive only when we are doing activities in network mode.

            if ($vm_deploy_mode -eq "network") {
                Remove-PSDrive Y
            }

        }
        else {
                              
            # This Session used for service backup.
             writeLog "[INFO]-SERVICE BACKUP STARTING..."
             write-host "[INFO]-SERVICE BACKUP STARTING..."

            $foldername = "Services"

            # dev This code will read value upto the network path.See below example
            # dev value=\\192.192.5.13\e$\Backups.substring("\\".getindexnumberofstring,"$".getindexnumberofstring)
            # dev This is used for check Vmdeplymode=local\network.

            if ($vm_deploy_mode -eq "network") {

                  $map_vm_drivepath = $vm_service_backup.substring($vm_service_backup.indexof("\\"), $vm_service_backup.IndexOf("$") + 1)

                   $vm_service_backup = $vm_service_backup.substring($vm_service_backup.indexof("$") + 1)

            # dev The New-PSDrive cmdlet functions similar to the Subst command: it enables you to map a drive 
            # dev (in this case, of course, a Windows PowerShell drive letter) to a path. 
            # dev For example, this command creates a new Windows PowerShell drive (drive X) 
            # dev that’s mapped to the folder C:\Scripts: 
            # dev New-PSDrive -name X -psprovider FileSystem -root c:\scripts
				
            # dev This is used for check Vmdeplymode=local\network.
            # dev The program will do map drive only when we are doing activities in network mode.

              New-psdrive Y filesystem $map_vm_drivepath -Credential $credentials

              $path = "Y:" + $vm_service_backup + "\" + $currentdate + "\" + $foldername
          
            } else {    
              
             # dev This path working for local mode.                                     
              $path = $vm_service_backup + "\" + $currentdate + "\" + $foldername
            }       

			# dev The folder already exist then that folder overwrite and if folder not exist then create new folder.
            # dev md $path used for create new folder on that's path.
            mkdir -Force -Path $path
				
            # dev to copy all the files we are append \* with vm_web_deploy param.
            # $currentservicepath = $vm_service_deploy + "\*"

             $currentservicepath = $vm_service_deploy 

            # dev Exclude folder (log,logs)

             $ExcludeFolderName = "Log,Logs"
             $files = Get-ChildItem $currentservicepath -Recurse
             $ExcludeFolders = $ExcludeFolderName.ToLower().Split(',')

             foreach ($file in $files) {

             $FileNameContains = $file.FullName.ToLower().Split('\')
             $IsInclude = "true"	

             foreach($ExcludeFolder in $ExcludeFolders) {

             if ($FileNameContains -contains $ExcludeFolder)
		      {

			    $IsInclude = "false"
			    break

		       }

             }

             if ($IsInclude -eq $true)
              {

                     # dev The Copy-Item cmdlet copies an item from one location to another location.
                     $CopyPath = Join-Path $path $file.FullName.Substring($currentservicepath.length) 
                     #Copy-Item -Force -Recurse $currentservicepath -Destination $CopyPath
                     Copy-Item $file.FullName -Destination $CopyPath -force
              }
	
	

             }
                

            # dev The Copy-Item cmdlet copies an item from one location to another location.
            #Copy-Item -Force -Recurse $currentservicepath -Destination $path
			
            writeLog "[INFO]-SERVICE BACKUP SUCCESSFULLY DONE..."	
            Write-output "[INFO]-SERVICE BACKUP SUCCESSFULLY DONE..."
				
            #dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
            #dev that were created by using the New-PSDrive cmdlet.
            # dev The program will do map drive only when we are doing activities in network mode.
            if ($vm_deploy_mode -eq "network") {
                Remove-PSDrive Y	
            }
		
        }
        
    }
    else {	
        writeLog "[ERROR]-$computer IS OFFLINE."
        Write-Output "[ERROR]-$computer IS OFFLINE." 
    }
}
