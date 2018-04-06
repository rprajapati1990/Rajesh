<# 
::@title This realease powershell program is called from the cygnet-ci--main  batch file 
  and used to release web and service latest code files to the vm release location.

::@author Rajesh Prajapati
::@date  21/01/2018
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$WhatToDeploy,
    [Parameter(Mandatory = $True, Position = 2)]
    [string]$inipath
)

# @dev this function used for read parameter from the config file.
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

# abhilash:Why it is hard code in the code?
# @dev read the full or hotfix ini file based on the @iniPath param which consist of database,vm and release path locations.
#$FileContent = Get-IniContent "D:\Projects\Live\CGSP01-GSP-DEVOPS\trunk\build source\Utilities\CIv1\phase2\ci-normal.ini"
$FileContent = Get-IniContent "$inipath"

# @dev read from ini file the setting values related to network from where the source is derived to release the latest files.
# @dev Get the AES key from the FileSystem
$key = (184,125,226,226,94,84,209,47,36,55,196,173,134,210,63,17,28,42,170,217,54,146,218,191,66,138,69,233,29,30,232,38)
#$network_build_source = $FileContent["network_build_source"] -replace '"', '' 
$network_web_release = $FileContent["network_web_release"] -replace '"', ''
$network_service_release = $FileContent["network_service_release"] -replace '"', '' 


# @dev read from ini file the setting values related to vm where the latest files  is copied from network source.
# @dev 3VM 
$vm_release_service = $FileContent["vm_release_service"] -replace '"', '' 
$vm_release_web = $FileContent["vm_release_web"] -replace '"', '' 
$vm_servername_db = $FileContent["vm_servername_db"] -replace '"', ''
$vm_servername_web = $FileContent["vm_servername_web"] -replace '"', ''
$vm_servername_app = $FileContent["vm_servername_app"] -replace '"', ''
$vm_web_deploy = $FileContent["vm_web_deploy"] -replace '"', ''
$vm_service_deploy = $FileContent["vm_service_deploy"] -replace '"', '' 

$currentdate = Get-Date -DisplayHint DateTime -Format dd.MM.yyyy

# @dev decrypt the windows username and  password  to established network drive connection.
# @dev decrypt the windows username and  password  to established network drive connection.
$network_win_password = ($FileContent["network_win_password"] -replace '"', '' | ConvertTo-SecureString -Key $key)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($network_win_password)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$network_win_user = ($FileContent["network_win_user"] -replace '"', '' | ConvertTo-SecureString -Key $key)
$network_win_password = ConvertTo-SecureString -AsPlainText -Force -String $PlainPassword
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($network_win_user)
$PlainUserName = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $PlainUserName, $network_win_password

# @dev  this key is used to decided the program is copying in network machine or local machine.
$vm_deploy_mode = $FileContent["vm_deploy_mode"] -replace '"', '' 
$vm_service_name = $FileContent["vm_service_name"] -replace '"', '' 

# @dev version.txt file path.
$network_version_path = $FileContent["network_version_path"] -replace '"', '' 

write-host "[INFO]-BUILD COPY SESSION STARTING..."

$version_file= $network_version_path
if($WhatToDeploy -eq "Website"){
$vm_servername=$vm_servername_web
} elseif($WhatToDeploy -eq "Services"){
$vm_servername=$vm_servername_app
}

# @dev if the vm deploy mode is network the program need to validate whether it could connect to vm machine with credential
# so below code part is used to establish the network drive connection with the website/service vm machine.
foreach ($computer in $vm_servername) {
    if (test-Connection -Cn $computer -quiet) {
		
        # dev The New-PSDrive cmdlet functions similar to the Subst command: it enables you to map a drive 
        # dev (in this case, of course, a Windows PowerShell drive letter) to a path. 
        # dev For example, this command creates a new Windows PowerShell drive (drive X) 
        # dev that’s mapped to the folder C:\Scripts: 
        # dev New-PSDrive -name X -psprovider FileSystem -root c:\scripts
				
        # dev The program will do map drive only when we are doing activities in network mode.
        # abhilash i am little confused here because what i understood was network will be shared to us.
        # vm machine we need to mapped drive and copy the code.However i am see network path here.
        
        if ($WhatToDeploy -eq "Services") {

        if ($vm_deploy_mode -eq "network") {

        #This is used for Services server build copy.
        # This code will read value upto the network path.See below example
        # Example value=\\192.192.5.13\e$\Backups.substring("\\".getindexnumberofstring,"$".getindexnumberofstring)

            $map_vm_drivepath = $vm_release_service.substring($vm_release_service.indexof("\\"), $vm_release_service.IndexOf("$") + 1)

            $vm_release_service_release = $vm_release_service.substring($vm_release_service.indexof("$") + 1)

            New-psdrive Y filesystem $map_vm_drivepath -Credential $credentials

            $destinationpath = "Y:" + $vm_release_service_release + "\" + $currentdate + "\" + "Services"

        } else{

            $destinationpath = $vm_release_service + "\" + $currentdate + "\" + "Services"
        
        }            
        #md $path used for create new folder on that's path.
        # dev The folder already exist then that folder overwrite and if folder not exist then create new folder.
        mkdir -Force -Path $destinationpath
				
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force -Recurse $network_service_release -Destination $destinationpath

        # dev This is used for version file copy in vm.
        if ($vm_deploy_mode -eq "network") {
                
       
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_service

		} else {

        
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_service
            
        }


				
        Write-output "[INFO]-BUILD COPY SUCCESSFULLY DONE..."
				
        # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
        # dev that were created by using the New-PSDrive cmdlet.
        if ($vm_deploy_mode -eq "network") {
            Remove-PSDrive Y
        }


} elseif ($WhatToDeploy -eq "Website") {
				
        # dev This is used for Web server build copy.

        # dev The program will do map drive only when we are doing activities in network mode.
        if ($vm_deploy_mode -eq "network") {
                		   
            $map_vm_drivepathweb = $vm_release_web.substring($vm_release_web.indexof("\\"), $vm_release_web.IndexOf("$") + 1)

            $vm_release_web_release = $vm_release_web.substring($vm_release_web.indexof("$") + 1)

            New-psdrive Y filesystem $map_vm_drivepathweb -Credential $credentials

            $destinationpath = "Y:" + $vm_release_web_release + "\" + $currentdate + "\" + "Website"


        } else{

         $destinationpath = $vm_release_web + "\" + $currentdate + "\" + "Website"	

        }
				
       
        # dev md $path used for create new folder on that's path.
        mkdir -Force -Path $destinationpath
				
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force -Recurse $network_web_release -Destination $destinationpath

        # dev This is used for version file copy in vm.
        if ($vm_deploy_mode -eq "network") {

        #$version_file= $network_web_release.substring($network_web_release.indexof("\\"), $network_web_release.IndexOf("$") + 2)+"\current\version.txt"
       
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_web

		} else {

        #$version_file = $network_web_release.substring(0,$network_web_release.IndexOf(":") + 1)+"\current\version.txt"

        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_web
            
        }		
        Write-output "[INFO]-BUILD COPY SUCCESSFULLY DONE..."
				
        # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
        # dev that were created by using the New-PSDrive cmdlet.
        if ($vm_deploy_mode -eq "network") {
            Remove-PSDrive Y
        }
		
    } elseif ($WhatToDeploy -eq "database") {
        
        # database build copy...

        # dev This is used for database server build copy.

        # dev The program will do map drive only when we are doing activities in network mode.
        if ($vm_deploy_mode -eq "network") {
                		   
            $map_vm_drivepathdb = $vm_release_db.substring($vm_release_db.indexof("\\"), $vm_release_db.IndexOf("$") + 1)

            $vm_release_db_release = $vm_release_db.substring($vm_release_db.indexof("$") + 1)

            New-psdrive Y filesystem $map_vm_drivepathdb -Credential $credentials

            $destinationpath = "Y:" + $vm_release_db_release + "\" + $currentdate + "\" + "Database"


        } else{

         $destinationpath = $vm_release_web + "\" + $currentdate + "\" + "Database"	

        }
				
       
        # dev md $path used for create new folder on that's path.
        mkdir -Force -Path $destinationpath
				
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force -Recurse $network_db_release -Destination $destinationpath

        # dev This is used for version file copy in vm.
        if ($vm_deploy_mode -eq "network") {

        #$version_file= $network_db_release.substring($network_db_release.indexof("\\"), $network_db_release.IndexOf("$") + 2)+"\current\version.txt"
       
        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_db

		} else {

        #$version_file = $network_db_release.substring(0,$network_db_release.IndexOf(":") + 1)+"\current\version.txt"

        # dev The Copy-Item cmdlet copies an item from one location to another location.
        Copy-Item -Force $version_file  -Destination $destinationpath
        Copy-Item -Force $version_file  -Destination $vm_release_db
            
        }
				
        Write-output "[INFO]-BUILD COPY SUCCESSFULLY DONE..."
				
        # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
        # dev that were created by using the New-PSDrive cmdlet.
        if ($vm_deploy_mode -eq "network") {
            Remove-PSDrive Y
        }


    } else {

        Write-Output "[ERROR]-$computer IS OFFLINE." 
    }

    }
}
 

if ($WhatToDeploy -eq "Services") {
    # dev Services stop
    write-host "[INFO]-SERVICES STOP SESSION STARTING..."

   #Write-Host $vm_service_name

   $vm_service_name="'$vm_service_name'"

   #Write-Host $vm_service_name

    foreach ($computer in $vm_servername) {
        if (test-Connection -Cn $computer -quiet) {
            $scriptblock = {
                    If (Get-Service | where {$_.Name -like $vm_service_name}) {
                    foreach ($Services in Get-Service | where {$_.name -like $vm_service_name}) {
                        If ($Services.Status -eq 'Running') {
                            Get-Service -Name $Services.Name| Stop-Service -ErrorAction SilentlyContinue -Force -Confirm:$false
                            $Services.Name + ' Stopped Successfully.'
                        }
                        else {
                            $Services.name + " : Service already in Stop mode."
                        }
                    }
                }
            }
            Invoke-Command -ComputerName $vm_servername -Credential $credentials -ScriptBlock $scriptBlock -ArgumentList $ServiceName
        }            
    }
}



#dev release folder overwrite

write-host "[INFO]-DEPLOY SESSION STARTING..."

foreach ($computer in $vm_servername) {
    if (test-Connection -Cn $computer -quiet) {
              
        if ($WhatToDeploy -eq "Website") {

            # dev This code will read value upto the network path.See below example
            # dev value=\\192.192.5.13\e$\Backups.substring("\\".getindexnumberofstring,"$".getindexnumberofstring)
            if ($vm_deploy_mode -eq "network") {

                 $map_vm_drivepath = $vm_web_deploy.substring($vm_web_deploy.indexof("\\"), $vm_web_deploy.IndexOf("$") + 1)

                 $vm_web_deploy = $vm_web_deploy.substring($vm_web_deploy.indexof("$") + 1)

                 New-psdrive Y filesystem $map_vm_drivepath -Credential $credentials

                 $destinationpath= $map_vm_drivepath + $vm_web_deploy


            } else {

             $destinationpath=  $vm_web_deploy

            }
                                     
            # dev The New-PSDrive cmdlet functions similar to the Subst command: it enables you to map a drive 
            # dev (in this case, of course, a Windows PowerShell drive letter) to a path. 
            # dev For example, this command creates a new Windows PowerShell drive (drive X) 
            # dev that’s mapped to the folder C:\Scripts: 
            # dev New-PSDrive -name X -psprovider FileSystem -root c:\scripts
            
                                
            # dev The Copy-Item cmdlet copies an item from one location to another location.
            Copy-Item -Force -Recurse -Verbose $network_web_release -Destination $destinationpath
				
            Write-output "[INFO]-WEBSITE DEPLOY SUCCESSFULLY DONE..."
				
            # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
            # dev that were created by using the New-PSDrive cmdlet.
            if ($vm_deploy_mode -eq "network") {
                Remove-PSDrive Y
            }

        }
        else {

                        
            # dev This code will read value upto the network path.See below example
            # dev value=\\192.192.5.13\e$\Backups.substring("\\".getindexnumberofstring,"$".getindexnumberofstring)

             if ($vm_deploy_mode -eq "network") {
                
                $map_vm_drivepath = $vm_service_deploy.substring($vm_service_deploy.indexof("\\"), $vm_service_deploy.IndexOf("$") + 1)

                 $vm_service_deploy = $vm_service_deploy.substring($vm_service_deploy.indexof("$") + 1)

                New-psdrive Y filesystem $map_vm_drivepath -Credential $credentials

                $destinationpath= $map_vm_drivepath + $vm_service_deploy   
                
            } else {

             $destinationpath= $vm_service_deploy 

            }
            				
            # dev The New-PSDrive cmdlet functions similar to the Subst command: it enables you to map a drive 
            # dev (in this case, of course, a Windows PowerShell drive letter) to a path. 
            # dev For example, this command creates a new Windows PowerShell drive (drive X) 
            # dev that’s mapped to the folder C:\Scripts: 
            # dev New-PSDrive -name X -psprovider FileSystem -root c:\scripts
				              
            #dev The Copy-Item cmdlet copies an item from one location to another location.
            Copy-Item -Force -Recurse -Verbose $network_service_release -Destination $destinationpath
				
            Write-output "[INFO]-SERVICE DEPLOY SUCCESSFULLY DONE..."
				
            # dev The Remove-PSDrive cmdlet deletes temporary Windows PowerShell drives 
            # dev that were created by using the New-PSDrive cmdlet.
            if ($vm_deploy_mode -eq "network") {
                Remove-PSDrive Y
            }

        }

    }
    else {
        Write-Output "[ERROR]-$computer IS OFFLINE." 
    }
}

if ($WhatToDeploy -eq "Services") {

    # dev Services start session
    write-host "[INFO]-SERVICES START SESSION STARTING..."

    $vm_service_name="'$vm_service_name'"

    foreach ($computer in $vm_servername) {

        if (test-Connection -Cn $computer -quiet) {
                    $scriptblock = {
                If (Get-Service | Where-Object {$_.Name -like $vm_service_name}) {
                    foreach ($Services in Get-Service | where {$_.name -like $vm_service_name}) {
                        If ($Services.Status -eq 'Stopped') {
                            Get-Service -Name $Services.Name| Start-Service -ErrorAction SilentlyContinue -Force -Confirm:$false
                            $Services.Name + ' Started Successfully.'
                        }
                        else {
                            $Services.name + " : Service already in Start mode."
                        }
                    }
                }
            }
            Invoke-Command -ComputerName $vm_servername -Credential $credentials -ScriptBlock $scriptBlock -ArgumentList $ServiceName
        }            
    }

}

