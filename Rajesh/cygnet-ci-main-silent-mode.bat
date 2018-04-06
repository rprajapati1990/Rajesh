
::@title This main script is the Starting point of CI.
::@author Avesh Khatri and Rajesh Prajapati
::@date 11/01/2018

@echo off
::@dev This below code is used for enabling the Delayed Expansion i.e. "set prerequisite_result_value[!n!]=%%i"
setlocal EnableDelayedExpansion
:mainProgram

::@dev This parameter is provided by the jenkins UI where the user select yes or no to confirm  to execute the build script.
if not "%Confirmation%"=="YES" (
echo "Warning:You have not selected Yes to executed the batch"
exit 1
)

::@dev This parameter is provided by the jenkins UI where the user select full or hotfix option accordingly the program run the script.
::@dev if release mode is full release the normal config for the setting.
::@abhilash please confirm that it is really neccessary to  provide full path instead of relative path
if "%Releasemode%"=="Full" (
set inipath=ci-normal.ini
)

::@dev This parameter is provided by the jenkins UI where the user select full or hotfix option accordingly the program run the script.
::@dev if release mode is hotfix release the normal config for the setting.
::@abhilash please confirm that it is really neccessary to  provide full path instead of relative path
if "%Releasemode%"=="Hotfix" (
set inipath=ci-hotfix.ini
)

::@dev This code part get the current date and format it like this 01.25.2018 and store in the currentdate variable.
::@dev We use this variable for the backup and release of build files in the vm machine's folder.
for /f "tokens=1-4 delims=/ " %%i in ("%date%") do (
	 set dow=%%i
     set month=%%j
     set day=%%k
     set year=%%l
)
set currentdate=%day%.%month%.%year%

echo ************************************************INIT MAIN PROGRAM****************************************************
echo.
	::@dev Read the common ini file which consist of powershell, sql and log files locations. 
	for /f "tokens=1,2 delims==" %%a in (ci-common.ini) do (
	if %%a==ci_prerequisite set ci_prerequisite=%%b
	if %%a==ci_dbbackupscript set ci_dbbackupscript=%%b
	if %%a==ci_dbsqlexecutor set ci_dbsqlexecutor=%%b
	if %%a==ci_clientdbbackup set ci_clientdbbackup=%%b
	if %%a==ci_backup set ci_backup=%%b
	if %%a==ci_release set ci_release=%%b
	if %%a==ci_dbtrasaction set ci_dbtrasaction=%%b
	if %%a==network_deployment_logs set network_deployment_logs=%%b
	if %%a==ci_prerequisite_result set ci_prerequisite_result=%%b
	)

	::@dev Read the full or hotfix ini file based on the @Releasemode param which consist of database,vm and release path locations. 
	for /f "tokens=1,2 delims==" %%a in (%inipath%) do (
	if %%a==vm_db_instance set vm_db_instance=%%b
	if %%a==network_db_release set network_db_release=%%b
	if %%a==network_client_db_release set network_client_db_release=%%b
	if %%a==vm_db_user set vm_db_user=%%b
	if %%a==vm_db_password set vm_db_password=%%b
	if %%a==vm_db_backup set vm_db_backup=%%b
	if %%a==vm_db_name set vm_db_name=%%b
	if %%a==vm_web_deploy set vm_web_deploy=%%b
	if %%a==vm_web_backup set vm_web_backup=%%b
	if %%a==vm_service_deploy set vm_service_deploy=%%b
	if %%a==vm_service_backup set vm_service_backup=%%b
	if %%a==network_web_release set network_web_release=%%b
	if %%a==network_service_release set network_service_release=%%b
	if %%a==copyFilestoRemoteScriptPath set copyFilestoRemoteScriptPath=%%b
	if %%a==vm_servername set vm_servername=%%b
	if %%a==sourcePathNetwork set sourcePathNetwork=%%b
	if %%a==vm_release_db set vm_release_db=%%b
	if %%a==network_win_password set network_win_password=%%b
	if %%a==network_win_user set network_win_user=%%b
	if %%a==releasePath set releasePath=%%b
	if %%a==serviceStopInNetworkScriptPath set serviceStopInNetworkScriptPath=%%b
	)
	
	::@dev append the current date in the @vm_db_backup variable.
	call set vm_db_backup=%%vm_db_backup:\*currentdate*\=\%currentdate%\%%

	::@dev append the current date in the @logsPathDate variable.
	set logsPathDate=%network_deployment_logs%\%currentdate%

	::@dev if log folder does not consist current date folder then create it else start the prequisite program.
	if exist %logsPathDate% goto submain
	mkdir %logsPathDate%

::@dev This command is used to asking the user what he wants to execute. User needs to enter a number according to the choice he/she wants to make.
::@dev Since program run in the silent mode we donot prompt user for the choice.
:submain
echo *******************************************PREREQUISITE PROGRAM**********************************
echo.
	::@dev This command is used to confirm db credential store in the ini is valid or not.
	::@abhilash We should check sql query based on the db which we has rather than master.
	echo [INFO]-CHECKING DATABASE CONNECTION FOR THE VM SQL INSTANCE ....
	sqlcmd /S %vm_db_instance% /d "master" -U %vm_db_user% -P %vm_db_password% /Q "select sum(1) from master.dbo.sysdatabases" 
	if errorlevel 1 exit 1
	echo [INFO]-VM SQL INSTANCE DATABASE IS CONNECTED..
	del "prerequisite_result.txt"
	Powershell.exe -executionpolicy Bypass -File %ci_prerequisite% %inipath% %Releasemode% %ci_prerequisite_result%
	::@dev Since the powershell file does not return value we used an alternative to handle return result i.e store storing
	::@dev the success and failure in the file and verfying it in the batch file.
	::@abhilash we need to change file naming convention from date.txt to prerequisiteresult.txt
	::@abhilash we need return multiple result value and based on it change the message.
	::@abhilash We need to store all the prequisite error code in below fashion let me example below
	:: let say if we have 12 validations and all are sucess then the ci_prerequisite_result value should 111111111111
	:: let say out of  12 validations 2 are failed and value are below
	:: 111111111100
	:: 0= web site folder is empty
	:: 0=service web site is empty
	:: In this condition we need to only run database program from the cygnet-ci-main rest will be excluded. This situation will come in hotfix situation.

	set n=0
	for /F "tokens=* delims=" %%i in (prerequisite_result.txt) do (
	set prerequisite_result_value[!n!]=%%i
	set /A n+=1
	)
	echo %prerequisite_result_value[0]% %prerequisite_result_value[1]% %prerequisite_result_value[2]% %prerequisite_result_value[3]% %prerequisite_result_value[4]% %prerequisite_result_value[5]% %prerequisite_result_value[6]% %prerequisite_result_value[7]% %prerequisite_result_value[8]%
	echo "[INFO-PREQUISITE VALIDATION INFORMATION]"
	echo .
	echo 1.--[%prerequisite_result_value[0]%]--DATABASE RELATED FILES ARE AVAILABLE IN THE NETWORK DATABASE FOLDER[0=FAIL,1=PASS]
	echo 2.--[%prerequisite_result_value[1]%]--WEBSITE  RELATED FILES ARE AVAILABLE IN THE NETWORK WEBSITE FOLDER[0=FAIL,1=PASS]
	echo 3.--[%prerequisite_result_value[2]%]--SERVICE RELATED FILES ARE AVAILABLE IN THE NETWORK SERVICE FOLDER[0=FAIL,1=PASS]
	echo 4.--[%prerequisite_result_value[3]%]--ESTBALISHING VM DRIVE CONNECTION FOR THE DATABASE BACKUP AND RELEASE PROGRAM[0=FAIL,1=PASS]
	echo 5.--[%prerequisite_result_value[4]%]--CHECKING VERSION OF CURRENT BUILD/HOTFIX/DATABASE WITH DEPLOYED BUILD/HOTFIX/DATABASE FOR DATABASE[0=FAIL,1=PASS]
	echo 6.--[%prerequisite_result_value[5]%]--ESTBALISHING VM DRIVE CONNECTION FOR THE WEBSITE BACKUP AND RELEASE PROGRAM[0=FAIL,1=PASS]
	echo 7.--[%prerequisite_result_value[6]%]--CHECKING VERSION OF CURRENT BUILD/HOTFIX/DATABASE WITH DEPLOYED BUILD/HOTFIX/DATABASE FOR WEBSITE[0=FAIL,1=PASS]
	echo 8.--[%prerequisite_result_value[7]%]--ESTBALISHING VM DRIVE CONNECTION FOR THE SERVICE BACKUP AND RELEASE PROGRAM[0=FAIL,1=PASS]
	echo 9.--[%prerequisite_result_value[8]%]--CHECKING VERSION OF CURRENT BUILD/HOTFIX/DATABASE WITH DEPLOYED BUILD/HOTFIX/DATABASE FOR SERVICES[0=FAIL,1=PASS]
echo *******************************************BACKUP PROGRAM*****************************************
echo.
	::@abhilash PREQUISITE RESULT VALUE SHOULD BE USED BEFORE RUNNING THE COMMAND
        ::@dev Run the backup script on the vm db instance and back all the database before the release start.
	if "%Action%"=="BACKUP" (
		goto All_backup
	)
	if "%Action%"=="RELEASE" (
			goto All_release
		)
	:All_backup
	if %prerequisite_result_value[0]%==1 (
		goto db_backup
	)
	:db_backup
	if %prerequisite_result_value[4]%==1 (
	echo [INFO]-VM DATABASE BACKUP UP STARTED...
	sqlcmd /S %vm_db_instance% /d "master" -U %vm_db_user% -P %vm_db_password% /i %ci_dbbackupscript% -v dbpath=%vm_db_backup% >> %logsPathDate%"\ci-mainLog.txt"
	if errorlevel 1 exit >> %logsPathDate%"\ci-mainLog.txt"
	echo [INFO]-VM DATABASE BACKUP UP DONE...
	echo.
	)
	
	::@abhilash PREQUISITE RESULT VALUE SHOULD BE USED BEFORE RUNNING THE COMMAND	
	::@dev Run the website backup program on the vm instance and back all the website files before the release start.	
	if %prerequisite_result_value[1]%==1 (
		goto web_backup
	)
	:web_backup
	if %prerequisite_result_value[6]%==1 (
	echo [INFO]-VM WEBSITE BACKUP UP STARTED...
	Powershell.exe -executionpolicy Bypass -File %ci_backup% "Website" %inipath%
	echo.
	echo [INFO]-VM WEBSITE BACKUP UP IS DONE...
	)
	::@abhilash PREQUISITE RESULT VALUE SHOULD BE USED BEFORE RUNNING THE COMMAND
	::@dev Run the service backup program on the vm instance and back all the service files before the release start.
	if %prerequisite_result_value[2]%==1 (
		goto service_backup
	)
	:service_backup
	if %prerequisite_result_value[8]%==1 (
	echo [INFO]-VM SERVICES BACKUP UP STARTED...
	Powershell.exe -executionpolicy Bypass -File %ci_backup% "Service" %inipath%
	echo.
	echo [INFO]-VM SERVICES BACKUP UP IS DONE...
	)
	goto END
echo *******************************************DATABASE RELEASE PROGRAM*************************************
	:All_release
	::@dev start the database release program on the vm db instance and excecute all the .sql files.	
	if %prerequisite_result_value[0]%==1 (
	goto db_release
	)
	if %prerequisite_result_value[0]%==0 (
	goto db_release_skip
	)
	:db_release
	if %prerequisite_result_value[4]%==1 (
		goto db_release_error
	)
	if %prerequisite_result_value[4]%==0 (
		goto db_release_skip
	)
	:db_release_error
		echo [INFO]-VM DATABASE RELEASE IS STARTED...
		powershell.exe -executionpolicy Bypass -File %ci_dbsqlexecutor% %vm_db_instance% %vm_db_name% %vm_db_user% %vm_db_password% %network_db_release% %network_client_db_release% %logsPathDate%
		for /F %%i in (date.txt) do set ci_dbrelease_result=%%i
			if %ci_dbrelease_result%==1 (
			echo [ERROR]-THERE IS ERROR IN DATABASE EXECUTION...
			exit 1
			)
			echo [INFO]-VM DATABASE RELEASE IS COMPLETED...
			
		::@abhilash PREQUISITE RESULT VALUE SHOULD BE USED BEFORE RUNNING THE COMMAND--DONE
		::@dev start the client database backup program on the vm db instance and back the client template db.
		sqlcmd /S %vm_db_instance% /d "master" -U %vm_db_user% -P %vm_db_password% /i %ci_clientdbbackup% >> %logsPathDate%"\ci-mainLog.txt"
		if errorlevel 1 exit 1
		
::@dev this program will run when Website program is selected and it will confirm whether you want to backup or release your website.
echo ************************************************WEBSITE RELEASE PROGRAM**************************************
	:db_release_skip
	if %prerequisite_result_value[1]%==1 (
		goto web_release
	)
	if %prerequisite_result_value[1]%==0 (
		goto web_release_skip
	)
	:web_release
	if %prerequisite_result_value[6]%==1 (
	echo [INFO]-VM WEBSITE RELEASE STARTED...
	Powershell.exe -executionpolicy Bypass -File %ci_release% "Website" %inipath%
	echo.
	echo [INFO]-VM WEBSITE RELEASE IS DONE...
	)
::@dev this program will run when Service program is selected and it will confirm whether you want to backup or release your Service.
echo **************************************************SERVICE PROGRAM**********************************************
	:web_release_skip
	if %prerequisite_result_value[2]%==1 (
		goto service_release
	)
	if %prerequisite_result_value[2]%==0 (
		goto END
	)
	:service_release
	if %prerequisite_result_value[8]%==1 (
	echo [INFO]-VM SERVICES RELEASE STARTED...
	Powershell.exe -executionpolicy Bypass -File %ci_release% "Services" %inipath%
	echo.
	echo [INFO]-VM SERVICES RELEASE IS DONE...
	)

:END
exit 