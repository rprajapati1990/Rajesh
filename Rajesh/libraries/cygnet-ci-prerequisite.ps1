<# 
::@title This prequisite powershell program is called from the cygnet-ci--main  batch file.
::@author Avesh Khatri and Rajesh Prajapati
::@date 11/01/2018

PREQUISITE PROGRAM VALIDATIONS
1.able to connect to vm_release_db and mapped drive with the credential or not.--done
2.able to connect to network_db_release and mapped drive with the credential or not.--no need
3.able to connect to vm_release_web and mapped drive with the credential.--done
4.able to connect to network_web_release and mapped drive with the credential or not.--no need
5.able to connect to vm_release_service and mapped drive with the credential--done
6.able to connect to network_service_release and mapped drive with the credential or not.--no need
7.validate currentVersionHash equal releaseVersionHash.--done
8.validate currenthotfix equal releasehotfix.--done
9.validate currentdatabase equal releasedatabase.--done
10.validate network_db_release is empty --done
11.validate network_web_release is empty --done
12.validate network_service_release is empty --done

PROBLEMS 
VALIDATIONs
    VALIDATION 2.4.6 why we require this
    VALIDATION 7.8.9 why we pass unc path rather using mapped drive logic
    VALIDATION 10.11.12 we need think how to solve when don't have db release in build or hotfix

GENERIC PROBLEM IN ERROR HANDLING 
    What would happen if mapped drive logic failed then do we continue the rest program or stop.
    There is no code with return value to the main batch file.

CODING PROBLEM
 e.g this variable is used vm_servername with the network_db_release variable.
 see below comment with #abhilash
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
	[string]$iniPath,
	[Parameter(Mandatory = $True, Position = 2)]
    [string]$Releasemode,
    [Parameter(Mandatory = $True, Position = 3)]
    [string]$ci_prerequisite_result
)
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
$FileContent = Get-IniContent $iniPath

# @dev Get the AES key from the FileSystem
$key = (184,125,226,226,94,84,209,47,36,55,196,173,134,210,63,17,28,42,170,217,54,146,218,191,66,138,69,233,29,30,232,38)

# @dev read from ini file the setting values related to network from where the source is derived to release the latest files.
$network_service_release = $FileContent["network_service_release"] -replace '"', ''
$network_db_release = $FileContent["network_db_release"] -replace '"', ''
$network_web_release = $FileContent["network_web_release"] -replace '"', ''
$network_version_path = $FileContent["network_version_path"] -replace '"', ''

# @dev read from ini file the setting values related to vm where the latest files  is copied from network source.
$vm_servername_db = $FileContent["vm_servername_db"] -replace '"', ''
$vm_servername_web = $FileContent["vm_servername_web"] -replace '"', ''
$vm_servername_app = $FileContent["vm_servername_app"] -replace '"', ''
$vm_release_db = $FileContent["vm_release_db"] -replace '"', ''
$vm_release_web = $FileContent["vm_release_web"] -replace '"', ''
$vm_release_service = $FileContent["vm_release_service"] -replace '"', ''
$vm_db_instance = $FileContent["vm_db_instance"] -replace '"', ''
$vm_db_user = $FileContent["vm_db_user"] -replace '"', ''
$vm_db_password = $FileContent["vm_db_password"] -replace '"', ''

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

# @dev if the vm deploy mode is network the program need to validate whether it could connect to vm machine with credential
# so below code part is used to establish the network drive connection with the database vm machine.
# @dev This below code part is used to validate the version file in the network and  vm machine.
# abhilash we should always check the files from the network using mapped drive rather than unc path.--done
# abhilash this code part should be either includede above during mapped drive creation.--done
# abhilash we have code part available in the ci-release section how the mapped drive and rest path is verified.--done

$currentVersionPath = $network_version_path
$currentVersionHash = @{}
$currentVersionContent = get-content $currentVersionPath
foreach ($line in $currentVersionContent) {
				$temp = $line.split('=')    
				$currentVersionHash.add($temp[0].trim().toString(), ($temp[1]).trim().toString())
}
# @dev This below code part is used to validate network db folder is empty or not.
$fileExist = Get-ChildItem -Path $network_db_release
if ($fileExist.count -gt 1) {
				write-host "[INFO]-DATABASE RELATED FILES ARE AVAILABLE IN THE NETWORK DATABASE FOLDER..."
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
else {
				write-host "[INFO]-DATABASE RELATED FILES ARE NOT AVAILABLE IN THE NETWORK DATABASE FOLDER..."
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
# @dev This below code part is used to validate network web folder is empty or not.
$fileExist = Get-ChildItem -Path $network_web_release
if ($fileExist.count -eq 0) {
				write-host "[INFO]-WEBSITE  RELATED FILES ARE NOT AVAILABLE IN THE NETWORK SERVICE  FOLDER..."
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
else {
				write-host "[INFO]-WEBSITE  RELATED FILES ARE AVAILABLE IN THE NETWORK SERVICE  FOLDER..."
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
# @dev This below code part is used to validate network service folder is empty or not.
$fileExist = Get-ChildItem -Path $network_service_release
if ($fileExist.count -eq 0) {
				write-host "[INFO]-SERVICE  RELATED FILES ARE NOT AVAILABLE IN THE NETWORK SERVICE  FOLDER..."
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
else {
				write-host "[INFO]-SERVICE  RELATED FILES ARE AVAILABLE IN THE NETWORK SERVICE  FOLDER..."
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
}
write-host "[INFO]-ESTBALISHING VM DRIVE CONNECTION FOR THE BACKUP AND RELEASE PROGRAM..."

foreach ($computer in $vm_servername_db) {
    if (test-Connection -Cn $computer -quiet) {
        # md $path -Force
        if ($vm_deploy_mode -eq "network") {
            New-psdrive Y filesystem $vm_release_db -Credential $credentials
            "1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
            Write-output "[INFO]-ESTBALISHED VM DRIVE CONNECTION ..."
            $path = "Y:"
        }
        else {
            $path = $vm_release_db
        }
        # @dev This below code part is used to validate the version file in the network and  vm machine.
        # abhilash we should always check the files from the network using mapped drive rather than unc path.--done
        # abhilash this code part should be either includede above during mapped drive creation.--done
        # abhilash we have code part available in the ci-release section how the mapped drive and rest path is verified.
			
        $releaseVersionPath = $path + "\version.txt"
        $releaseVersionHash = @{}
        $releaseVersionContent = get-content $releaseVersionPath
        foreach ($line in $releaseVersionContent) {
            $temp = $line.split('=')    
            $releaseVersionHash.add($temp[0].trim().toString(), ($temp[1]).trim().toString())
        }
        # @dev This below code part is used to validate the db version  against the database.
        $result = Invoke-sqlcmd -ServerInstance $vm_db_instance -Username $vm_db_user -Password $vm_db_password -query "USE [CygnetGSPMetadata] select [Value] from dbo.GlobalDBSettings where [Key] = 'CurrentDBVersion'"
        write-host "Deployed database version="$result.Value
        if ($currentVersionHash.build -eq $releaseVersionHash.build) {
			# @dev This below code part is used to validate the hotfix version against the vm version file.
			if ($currentVersionHash.hotfix -gt $releaseVersionHash.hotfix -and $Releasemode -eq 'Hotfix') {
				# @dev This below code part is used to validate the db version file against the vm version file.
				if ([version]$currentVersionHash.database -gt [version]$result.Value) {
					write-host need to update this dbScripts...
					"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
				}
				else {
					write-host This dbScripts is already deployed....
					"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
				}
			}
			else {
				write-host This hotfix is already deployed....
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
        }
        elseif($currentVersionHash.build -gt $releaseVersionHash.build -and $Releasemode -eq 'Full') {
            # @dev This below code part is used to validate the db version file against the vm version file.
			if ([version]$currentVersionHash.database -gt [version]$result.Value) {
				write-host need to update this dbScripts...
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
			else {
				write-host This dbScripts is already deployed....
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
		}
		else{
			write-host This build is already deployed....
            "0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		}
        Remove-PSDrive Y
    }
    else {	
        Write-Output "$computer is offline" 
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
    }
}
# @dev This below code part is used to establish the network drive connection with the database vm machine.
foreach ($computer in $vm_servername_web) {
    if (test-Connection -Cn $computer -quiet) {
                
           
        if ($vm_deploy_mode -eq "network") {
            New-psdrive Y filesystem $vm_release_web -Credential $credentials
            "1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
            Write-output "[INFO]-ESTBALISHED VM DRIVE CONNECTION ..."
            $path = "Y:"
        }
        else {
            $path = $vm_release_web
        }
			
        # @dev This below code part is used to validate the version file in the network and  vm machine.
        # abhilash we should always check the files from the network using mapped drive rather than unc path.--done
        # abhilash this code part should be either includede above during mapped drive creation.--done
        # abhilash we have code part available in the ci-release section how the mapped drive and rest path is verified.--done

        $releaseVersionPath = $path + "\version.txt"
        $releaseVersionHash = @{}
        $releaseVersionContent = get-content $releaseVersionPath
        foreach ($line in $releaseVersionContent) {
            $temp = $line.split('=')    
            $releaseVersionHash.add($temp[0].trim().toString(), ($temp[1]).trim().toString())
        }
        if ($currentVersionHash.build -eq $releaseVersionHash.build) {
			# @dev This below code part is used to validate the hotfix version against the vm version file.
			if ($currentVersionHash.hotfix -gt $releaseVersionHash.hotfix) {
				write-host need to update this hotfix....
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
			else {
				write-host This hotfix is already deployed....
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
        }
        elseif($currentVersionHash.build -gt $releaseVersionHash.build) {
            write-host need to update this build....
            "1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		}
		else{
			write-host This build is already deployed....
            "0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		}
        Remove-PSDrive Y
    }
    else {	
        Write-Output "$computer is offline" 
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
    }
}
# @dev This below code part is used to establish the network drive connection with the service vm machine.
# abhilash litte confused with above and below code.
foreach ($computer in $vm_servername_app) {
    if (test-Connection -Cn $computer -quiet) {
           
            
            
        if ($vm_deploy_mode -eq "network") {
            New-psdrive Y filesystem $vm_release_service -Credential $credentials
            "1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
            Write-output "[INFO]-ESTBALISHED VM DRIVE CONNECTION ..."
            $path = "Y:"
        }
        else {
            $path = $vm_release_service
        }
			
        # @dev This below code part is used to validate the version file in the network and  vm machine.
        # abhilash we should always check the files from the network using mapped drive rather than unc path.
        # abhilash this code part should be either includede above during mapped drive creation.
        # abhilash we have code part available in the ci-release section how the mapped drive and rest path is verified.

        $releaseVersionPath = $path + "\version.txt"
        $releaseVersionHash = @{}
        $releaseVersionContent = get-content $releaseVersionPath
        foreach ($line in $releaseVersionContent) {
            $temp = $line.split('=')    
            $releaseVersionHash.add($temp[0].trim().toString(), ($temp[1]).trim().toString())
        }
		if ($currentVersionHash.build -eq $releaseVersionHash.build) {
			# @dev This below code part is used to validate the hotfix version against the vm version file.
			if ($currentVersionHash.hotfix -gt $releaseVersionHash.hotfix) {
				write-host need to update this hotfix....
				"1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
			else {
				write-host This hotfix is already deployed....
				"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
			}
        }
        elseif($currentVersionHash.build -gt $releaseVersionHash.build) {
            write-host need to update this build....
            "1" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		}
		else{
			write-host This build is already deployed....
            "0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		}
        Remove-PSDrive Y
    }
    else {	
        Write-Output "$computer is offline" 
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
		"0" | Out-File -append -FilePath $ci_prerequisite_result -Encoding 'ASCII'
    }
}
