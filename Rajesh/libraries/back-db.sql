USE master
GO

BEGIN

DECLARE @name VARCHAR(50) -- database name  
DECLARE @path VARCHAR(256) -- path for backup files  
DECLARE @fileName VARCHAR(256) -- filename for backup  
DECLARE @fileDate VARCHAR(20) -- used for file name
DECLARE @CurrentDate VARCHAR(20) -- To store the currentdate for creating folder in backups
-- specify filename format
SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112)
SELECT @CurrentDate=CONVERT(VARCHAR(10), SYSDATETIME(), 104)
-- specify database backup directory
SET @path = '$(dbpath)'
print @path

exec master.dbo.xp_create_subdir @path

DECLARE db_cursor CURSOR READ_ONLY FOR  

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   
 
WHILE @@FETCH_STATUS = 0   
BEGIN   
   SET @fileName = @path + @name + '.bak'  
   BACKUP DATABASE @name TO DISK = @fileName  
   FETCH NEXT FROM db_cursor INTO @name   
END
 
CLOSE db_cursor   
DEALLOCATE db_cursor

END
