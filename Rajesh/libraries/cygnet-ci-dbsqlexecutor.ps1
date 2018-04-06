

#@todo lower case keywords, dev comments for each commands(executionpolicy), variable naming
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$vm_db_instance,
    [Parameter(Mandatory = $True, Position = 2)]
    [string]$vm_db_name,
    [Parameter(Mandatory = $True, Position = 3)]
    [string]$vm_db_user,
    [Parameter(Mandatory = $True, Position = 4)]
    [string]$vm_db_password,
    [Parameter(Mandatory = $True, Position = 5)]
    [string]$network_db_release,
    [Parameter(Mandatory = $True, Position = 6)]
    [string]$network_client_db_release,
    [Parameter(Mandatory = $True, Position = 7)]
    [string]$network_deployment_logs
)
try {
    $dbProgramCommand = 2
    $env:r = 0
    # write-host $vm_db_instance $vm_db_name $vm_db_user $vm_db_password $network_db_release $network_client_db_release $network_deployment_logs $numberofClientDb
    # $dbProgramCommand=1
    # $vm_db_instance="localhost"
    # $vm_db_name="master"
    # $cmd="$network_db_release"\*.sql
    # $network_db_release="D:\Avesh\db1"
    # $logs=$network_deployment_logs+"\ci-databaseLog_$(get-date -format `"yyyyMMdd_hhmmsstt`")_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
    $cmd = Get-ChildItem -Path $network_db_release -filter *.sql 
    # write-host "$cmd"
    $count = 0
    foreach ($x in $cmd) {
        $count++
    } 
    $cnt = $count
    $cmdClient = Get-ChildItem -Path $network_client_db_release -filter *.sql 
    # write-host "$cmd"
    $countClient = 0
    foreach ($y in $cmdClient) {
        $countClient++
    } 
    $cntClient = $countClient
    # $list = Get-ChildItem -Path $network_db_release -recurse -filter *client*
    # write-host $list
    write-host Total db script in release folder =: "$count"
    write-host "Your db Update will be start now..."


    if ($dbProgramCommand -eq 1) {
        for ($i = 1; $i -le $cnt; $i++) {
            foreach ($G in (Get-ChildItem -Path $network_db_release -filter $i*.sql)) { 
                $Name = $network_db_release + "\" + $G
                write-host $Name
                $scripts = Get-ChildItem $Name |Sort-Object
                write-host $script
                $fullbatch = Get-Content $scripts
                cmd /c pause
                # $fullbatch += "BEGIN TRANSACTION
                # if(@@TRANCOUNT > 0)
                # SAVE TRANSACTION CISAVEPOINT
                # BEGIN TRY"

                # foreach($script in $scripts){
                # $fullbatch += Get-Content $scripts
			
                # }

                # $fullbatch += "
                # if(@@TRANCOUNT > 0) COMMIT TRANSACTION ELSE ROLLBACK TRANSACTION
                # END TRY
                # BEGIN CATCH
                # ROLLBACK TRANSACTION CISAVEPOINT
                # END CATCH
                # "
                # $fullbatch = $fullbatch -replace "GO","--GO"
                $logs = $network_deployment_logs + "\ci-databaseLog_" + $G + "_$(get-date -format `"yyyyMMdd_hhmmsstt`")_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
                write $fullbatch > out.sql
                $sqlerror = sqlcmd /S $vm_db_instance /d $vm_db_name -i "out.sql" >> $logs
                $SEL = Select-String $logs -Pattern msg
                if ($SEL -ne $null) {
                    write-host "Error found in "+$Name
                    write-host $SEL
                    cmd /c pause
                    cmd /c exit
                }
                else {
                    write-host "There is no error found, Execution is Successful."
                }
            }
        }
        $result = Invoke-sqlcmd -query "use[master]
			SELECT name 
			FROM master.dbo.sysdatabases 
			WHERE Name LIKE '%CygnetGSPClient%'" 
			
        for ($i = 1; $i -le $cntClient; $i++) {
            foreach ($item in $result) { 
                foreach ($G in (Get-ChildItem -Path $network_client_db_release -filter $i*.sql)) {
                    $NameClient = $network_client_db_release + "\" + $G
                    $scripts = Get-ChildItem $NameClient |Sort-Object
                    $fullbatch = Get-Content $scripts
                    # $fullbatch += "BEGIN TRANSACTION
                    # if(@@TRANCOUNT > 0)
                    # SAVE TRANSACTION CISAVEPOINT
                    # BEGIN TRY"

                    # foreach($script in $scripts){
                    # $fullbatch += Get-Content $scripts
					
                    # }

                    # $fullbatch += "
                    # if(@@TRANCOUNT > 0) COMMIT TRANSACTION ELSE ROLLBACK TRANSACTION
                    # END TRY
                    # BEGIN CATCH
                    # ROLLBACK TRANSACTION CISAVEPOINT
                    # END CATCH
                    # "
                    # $fullbatch = $fullbatch -replace "GO","--GO"
                    $logs = $network_deployment_logs + "\ci-databaseLog_" + $G + "_$(get-date -format `"yyyyMMdd_hhmmsstt`")_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
                    write $fullbatch > out.sql
                    $sqlerror = sqlcmd /S $vm_db_instance /d $item.name -E -i "out.sql" >> $logs
                    $SEL = Select-String $logs -Pattern msg
                    if ($SEL -ne $null) {
                        write-host "Error found"+$SEL
                        cmd /c exit
                    }
                    else {
                        write-host "There is no error found, Execution is Successful."
                    }
                }
            }
        }

    }
    elseif ($dbProgramCommand -eq 2) {
        for ($i = 1; $i -le $cnt; $i++) {
            foreach ($G in (Get-ChildItem -Path $network_db_release -filter $i*.sql)) { 
                $Name = $network_db_release + "\" + $G
                $scripts = Get-ChildItem $Name |Sort-Object
                $fullbatch = Get-Content $scripts
                # $fullbatch += "BEGIN TRANSACTION
                # if(@@TRANCOUNT > 0)
                # SAVE TRANSACTION CISAVEPOINT
                # BEGIN TRY"

                # foreach($script in $scripts){
                # $fullbatch += Get-Content $scripts
			
                # }

                # $fullbatch += "
                # if(@@TRANCOUNT > 0) COMMIT TRANSACTION ELSE ROLLBACK TRANSACTION
                # END TRY
                # BEGIN CATCH
                # ROLLBACK TRANSACTION CISAVEPOINT
                # THROW;
                # END CATCH
                # "
                # $fullbatch = $fullbatch -replace "GO","--GO"
                $logs = $network_deployment_logs + "\ci-databaseLog_" + $G + "_$(get-date -format `"yyyyMMdd_hhmmsstt`")_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
                write $fullbatch > out.sql
                $sqlerror = sqlcmd /S $vm_db_instance /d $vm_db_name -U $vm_db_user -P $vm_db_password -i "out.sql" >> $logs
                $SEL = Select-String $logs -Pattern msg
                if ($SEL -ne $null) {
                    write-host "[ERROR]-"+$SEL
                    "1" | Out-File -FilePath ./date.txt -Encoding 'ASCII'
					exit;
                }
                else {
                    write-host "[INFO]-THERE IS NO ERROR FOUND,EXECUTION IS SUCCESSFFUL."
					"0" | Out-File -FilePath ./date.txt -Encoding 'ASCII'
                }
            }
        }
        $result = Invoke-sqlcmd -query "use[master]
			SELECT name 
			FROM master.dbo.sysdatabases 
			WHERE Name LIKE '%CygnetGSPClient%'" 
        for ($i = 1; $i -le $cntClient; $i++) {
            foreach ($item in $result) {  
                foreach ($G in (Get-ChildItem -Path $network_client_db_release -filter $i*.sql)) {
                    $NameClient = $network_client_db_release + "\" + $G
                    $scripts = Get-ChildItem $NameClient |Sort-Object
                    $fullbatch = Get-Content $scripts
                    # $fullbatch += "BEGIN TRANSACTION
                    # if(@@TRANCOUNT > 0)
                    # SAVE TRANSACTION CISAVEPOINT
                    # BEGIN TRY"

                    # foreach($script in $scripts){
                    # $fullbatch += Get-Content $scripts
					
                    # }

                    # $fullbatch += "
                    # if(@@TRANCOUNT > 0) COMMIT TRANSACTION ELSE ROLLBACK TRANSACTION
                    # END TRY
                    # BEGIN CATCH
                    # ROLLBACK TRANSACTION CISAVEPOINT
                    # THROW; 
                    # END CATCH
                    # "
                    # $fullbatch = $fullbatch -replace "GO","--GO"
                    $logs = $network_deployment_logs + "\ci-databaseLog_" + $G + "_$(get-date -format `"yyyyMMdd_hhmmsstt`")_$(get-date -format `"yyyyMMdd_hhmmsstt`").txt"
                    write $fullbatch > out.sql
                    $sqlerror = sqlcmd /S $vm_db_instance /d $item.name -U $vm_db_user -P $vm_db_password -i "out.sql" >> $logs
                    $SEL = Select-String $logs -Pattern msg
                    if ($SEL -ne $null) {
                        write-host "Error found"+$SEL
                        "1" | Out-File -FilePath ./date.txt -Encoding 'ASCII'
						exit;
                    }
                    else {
                        write-host "[INFO]-THERE IS NO ERROR FOUND,EXECUTION IS SUCCESSFFUL."
						"0" | Out-File -FilePath ./date.txt -Encoding 'ASCII'
                    }
                }
            }
        }
    }
}
catch [System.Exception] {
    write-Host "[ERROR]-GENERAL EXCEPTION $callingmodule WHILE PROCESSING $PSItem"  
}

