Use [CygnetGSPMetadata]
GO
DECLARE @BackupPath VARCHAR(200)
SELECT @BackupPath=[Value] FROM GlobalDBSettings where ID=8 and [Key]='ClientDBTemplatePath'
PRINT @BackupPath
-- Backup Script for default location template db
Use [master]
BACKUP DATABASE [CygnetGSPClient] TO  DISK = @BackupPath
WITH NOFORMAT, INIT,  NAME = N'CygnetGSPClient-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
