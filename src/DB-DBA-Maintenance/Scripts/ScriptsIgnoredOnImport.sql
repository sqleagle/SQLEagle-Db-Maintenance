
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog]') AND type in (N'U'))
BEGIN
--The following statement was imported into the database project as a schema object and named dbo.CommandLog.
--CREATE TABLE [dbo].[CommandLog](
--  [ID] [int] IDENTITY(1,1) NOT NULL,
--  [DatabaseName] [sysname] NULL,
--  [SchemaName] [sysname] NULL,
--  [ObjectName] [sysname] NULL,
--  [ObjectType] [char](2) NULL,
--  [IndexName] [sysname] NULL,
--  [IndexType] [tinyint] NULL,
--  [StatisticsName] [sysname] NULL,
--  [PartitionNumber] [int] NULL,
--  [ExtendedInfo] [xml] NULL,
--  [Command] [nvarchar](max) NOT NULL,
--  [CommandType] [nvarchar](60) NOT NULL,
--  [StartTime] [datetime2](7) NOT NULL,
--  [EndTime] [datetime2](7) NULL,
--  [ErrorNumber] [int] NULL,
--  [ErrorMessage] [nvarchar](max) NULL,
-- CONSTRAINT [PK_CommandLog] PRIMARY KEY CLUSTERED
--(
--  [ID] ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
--)
    PRINT '';
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandExecute]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CommandExecute] AS'
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackup]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DatabaseBackup] AS'
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseIntegrityCheck]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DatabaseIntegrityCheck] AS'
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexOptimize]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IndexOptimize] AS'
END
GO

IF (SELECT [Value] FROM #Config WHERE Name = 'CreateJobs') = 'Y'
    AND SERVERPROPERTY('EngineEdition') NOT IN(4, 5)
    AND (IS_SRVROLEMEMBER('sysadmin') = 1 OR (EXISTS (SELECT * FROM sys.databases WHERE [name] = 'rdsadmin') AND SUSER_SNAME(0x01) = 'rdsa'))
    AND (SELECT [compatibility_level] FROM sys.databases WHERE [name] = DB_NAME()) >= 90
    AND NOT (EXISTS (SELECT * FROM #Config WHERE Name = 'BackupDirectory' AND [Value] IS NOT NULL) AND EXISTS (SELECT * FROM #Config WHERE Name = 'BackupURL' AND [Value] IS NOT NULL))
    AND NOT (EXISTS (SELECT * FROM #Config WHERE Name = 'BackupURL' AND [Value] IS NOT NULL) AND EXISTS (SELECT * FROM #Config WHERE Name = 'CleanupTime' AND [Value] IS NOT NULL))
BEGIN

  DECLARE @BackupDirectory nvarchar(max)
  DECLARE @BackupURL nvarchar(max)
  DECLARE @CleanupTime int
  DECLARE @OutputFileDirectory nvarchar(max)
  DECLARE @LogToTable nvarchar(max)
  DECLARE @DatabaseName nvarchar(max)

  DECLARE @HostPlatform nvarchar(max)
  DECLARE @DirectorySeparator nvarchar(max)
  DECLARE @LogDirectory nvarchar(max)

  DECLARE @TokenServer nvarchar(max)
  DECLARE @TokenJobID nvarchar(max)
  DECLARE @TokenJobName nvarchar(max)
  DECLARE @TokenStepID nvarchar(max)
  DECLARE @TokenStepName nvarchar(max)
  DECLARE @TokenDate nvarchar(max)
  DECLARE @TokenTime nvarchar(max)
  DECLARE @TokenLogDirectory nvarchar(max)

  DECLARE @JobDescription nvarchar(max)
  DECLARE @JobCategory nvarchar(max)
  DECLARE @JobOwner nvarchar(max)

  DECLARE @Jobs TABLE (JobID int IDENTITY,
                       [Name] nvarchar(max),
                       CommandTSQL nvarchar(max),
                       CommandCmdExec nvarchar(max),
                       DatabaseName varchar(max),
                       OutputFileNamePart01 nvarchar(max),
                       OutputFileNamePart02 nvarchar(max),
                       Selected bit DEFAULT 0,
                       Completed bit DEFAULT 0)

  DECLARE @CurrentJobID int
  DECLARE @CurrentJobName nvarchar(max)
  DECLARE @CurrentCommandTSQL nvarchar(max)
  DECLARE @CurrentCommandCmdExec nvarchar(max)
  DECLARE @CurrentDatabaseName nvarchar(max)
  DECLARE @CurrentOutputFileNamePart01 nvarchar(max)
  DECLARE @CurrentOutputFileNamePart02 nvarchar(max)

  DECLARE @CurrentJobStepCommand nvarchar(max)
  DECLARE @CurrentJobStepSubSystem nvarchar(max)
  DECLARE @CurrentJobStepDatabaseName nvarchar(max)
  DECLARE @CurrentOutputFileName nvarchar(max)

  DECLARE @Version numeric(18,10) = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

  DECLARE @AmazonRDS bit = CASE WHEN SERVERPROPERTY('EngineEdition') IN (5, 8) THEN 0 WHEN EXISTS (SELECT * FROM sys.databases WHERE [name] = 'rdsadmin') AND SUSER_SNAME(0x01) = 'rdsa' THEN 1 ELSE 0 END

  IF @Version >= 14
  BEGIN
    SELECT @HostPlatform = host_platform
    FROM sys.dm_os_host_info
  END
  ELSE
  BEGIN
    SET @HostPlatform = 'Windows'
  END

  SELECT @DirectorySeparator = CASE
  WHEN @HostPlatform = 'Windows' THEN '\'
  WHEN @HostPlatform = 'Linux' THEN '/'
  END

  SET @TokenServer = '$' + '(ESCAPE_SQUOTE(SRVR))'
  SET @TokenJobID = '$' + '(ESCAPE_SQUOTE(JOBID))'
  SET @TokenStepID = '$' + '(ESCAPE_SQUOTE(STEPID))'
  SET @TokenDate = '$' + '(ESCAPE_SQUOTE(DATE))'
  SET @TokenTime = '$' + '(ESCAPE_SQUOTE(TIME))'

  IF @Version >= 13
  BEGIN
    SET @TokenJobName = '$' + '(ESCAPE_SQUOTE(JOBNAME))'
    SET @TokenStepName = '$' + '(ESCAPE_SQUOTE(STEPNAME))'
  END

  IF @Version >= 12 AND @HostPlatform = 'Windows'
  BEGIN
    SET @TokenLogDirectory = '$' + '(ESCAPE_SQUOTE(SQLLOGDIR))'
  END

  SELECT @BackupDirectory = Value
  FROM #Config
  WHERE [Name] = 'BackupDirectory'

  SELECT @BackupURL = Value
  FROM #Config
  WHERE [Name] = 'BackupURL'

  SELECT @CleanupTime = Value
  FROM #Config
  WHERE [Name] = 'CleanupTime'

  SELECT @OutputFileDirectory = Value
  FROM #Config
  WHERE [Name] = 'OutputFileDirectory'

  SELECT @LogToTable = Value
  FROM #Config
  WHERE [Name] = 'LogToTable'

  SELECT @DatabaseName = Value
  FROM #Config
  WHERE [Name] = 'DatabaseName'

  IF @Version >= 11
  BEGIN
    SELECT @LogDirectory = [path]
    FROM sys.dm_os_server_diagnostics_log_configurations
  END
  ELSE
  BEGIN
    SELECT @LogDirectory = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max)))))
  END

  IF @OutputFileDirectory IS NOT NULL AND RIGHT(@OutputFileDirectory,1) = @DirectorySeparator
  BEGIN
    SET @OutputFileDirectory = LEFT(@OutputFileDirectory, LEN(@OutputFileDirectory) - 1)
  END

  IF @LogDirectory IS NOT NULL AND RIGHT(@LogDirectory,1) = @DirectorySeparator
  BEGIN
    SET @LogDirectory = LEFT(@LogDirectory, LEN(@LogDirectory) - 1)
  END

  SET @JobDescription = 'Source: https://ola.hallengren.com'
  SET @JobCategory = 'Database Maintenance'

  IF @AmazonRDS = 0
  BEGIN
    SET @JobOwner = SUSER_SNAME(0x01)
  END

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01, OutputFileNamePart02)
  SELECT 'DatabaseBackup - SYSTEM_DATABASES - FULL',
         'EXECUTE [dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + '@Databases = ''SYSTEM_DATABASES'',' + CHAR(13) + CHAR(10) + CASE WHEN @BackupURL IS NOT NULL THEN '@URL = N''' + REPLACE(@BackupURL,'''','''''') + '''' ELSE '@Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') END + ',' + CHAR(13) + CHAR(10) + '@BackupType = ''FULL'',' + CHAR(13) + CHAR(10) + '@Verify = ''Y'',' + CHAR(13) + CHAR(10) + '@CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ',' + CHAR(13) + CHAR(10) + '@Checksum = ''Y'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'DatabaseBackup',
         'FULL'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01, OutputFileNamePart02)
  SELECT 'DatabaseBackup - USER_DATABASES - DIFF',
         'EXECUTE [dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + '@Databases = ''USER_DATABASES'',' + CHAR(13) + CHAR(10) + CASE WHEN @BackupURL IS NOT NULL THEN '@URL = N''' + REPLACE(@BackupURL,'''','''''') + '''' ELSE '@Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') END + ',' + CHAR(13) + CHAR(10) + '@BackupType = ''DIFF'',' + CHAR(13) + CHAR(10) + '@Verify = ''Y'',' + CHAR(13) + CHAR(10) + '@CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ',' + CHAR(13) + CHAR(10) + '@Checksum = ''Y'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
          @DatabaseName,
         'DatabaseBackup',
         'DIFF'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01, OutputFileNamePart02)
  SELECT 'DatabaseBackup - USER_DATABASES - FULL',
         'EXECUTE [dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + '@Databases = ''USER_DATABASES'',' + CHAR(13) + CHAR(10) + CASE WHEN @BackupURL IS NOT NULL THEN '@URL = N''' + REPLACE(@BackupURL,'''','''''') + '''' ELSE '@Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') END + ',' + CHAR(13) + CHAR(10) + '@BackupType = ''FULL'',' + CHAR(13) + CHAR(10) + '@Verify = ''Y'',' + CHAR(13) + CHAR(10) + '@CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ',' + CHAR(13) + CHAR(10) + '@Checksum = ''Y'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'DatabaseBackup',
         'FULL'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01, OutputFileNamePart02)
  SELECT 'DatabaseBackup - USER_DATABASES - LOG',
         'EXECUTE [dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + '@Databases = ''USER_DATABASES'',' + CHAR(13) + CHAR(10) + CASE WHEN @BackupURL IS NOT NULL THEN '@URL = N''' + REPLACE(@BackupURL,'''','''''') + '''' ELSE '@Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') END + ',' + CHAR(13) + CHAR(10) + '@BackupType = ''LOG'',' + CHAR(13) + CHAR(10) + '@Verify = ''Y'',' + CHAR(13) + CHAR(10) + '@CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ',' + CHAR(13) + CHAR(10) + '@Checksum = ''Y'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'DatabaseBackup',
         'LOG'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'DatabaseIntegrityCheck - SYSTEM_DATABASES',
         'EXECUTE [dbo].[DatabaseIntegrityCheck]' + CHAR(13) + CHAR(10) + '@Databases = ''SYSTEM_DATABASES'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'DatabaseIntegrityCheck'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'DatabaseIntegrityCheck - USER_DATABASES',
         'EXECUTE [dbo].[DatabaseIntegrityCheck]' + CHAR(13) + CHAR(10) + '@Databases = ''USER_DATABASES'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'DatabaseIntegrityCheck'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'IndexOptimize - USER_DATABASES',
         'EXECUTE [dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + '@Databases = ''USER_DATABASES'',' + CHAR(13) + CHAR(10) + '@LogToTable = ''' + @LogToTable + '''',
         @DatabaseName,
         'IndexOptimize'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'sp_delete_backuphistory',
         'DECLARE @CleanupDate datetime' + CHAR(13) + CHAR(10) + 'SET @CleanupDate = DATEADD(dd,-30,GETDATE())' + CHAR(13) + CHAR(10) + 'EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate',
         'msdb',
         'sp_delete_backuphistory'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'sp_purge_jobhistory',
         'DECLARE @CleanupDate datetime' + CHAR(13) + CHAR(10) + 'SET @CleanupDate = DATEADD(dd,-30,GETDATE())' + CHAR(13) + CHAR(10) + 'EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate',
         'msdb',
         'sp_purge_jobhistory'

  INSERT INTO @Jobs ([Name], CommandTSQL, DatabaseName, OutputFileNamePart01)
  SELECT 'CommandLog Cleanup',
         'DELETE FROM [dbo].[CommandLog]' + CHAR(13) + CHAR(10) + 'WHERE StartTime < DATEADD(dd,-30,GETDATE())',
         @DatabaseName,
         'CommandLogCleanup'

  INSERT INTO @Jobs ([Name], CommandCmdExec, OutputFileNamePart01)
  SELECT 'Output File Cleanup',
         'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + '" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + '"\%v echo del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + '"\%v& del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + '"\%v"',
         'OutputFileCleanup'

  IF @AmazonRDS = 1
  BEGIN
   UPDATE @Jobs
   SET Selected = 1
   WHERE [Name] IN('DatabaseIntegrityCheck - USER_DATABASES','IndexOptimize - USER_DATABASES','CommandLog Cleanup')
  END
  ELSE IF SERVERPROPERTY('EngineEdition') = 8
  BEGIN
   UPDATE @Jobs
   SET Selected = 1
   WHERE [Name] IN('DatabaseIntegrityCheck - SYSTEM_DATABASES','DatabaseIntegrityCheck - USER_DATABASES','IndexOptimize - USER_DATABASES','CommandLog Cleanup','sp_delete_backuphistory','sp_purge_jobhistory')
  END
  ELSE IF @HostPlatform = 'Windows'
  BEGIN
   UPDATE @Jobs
   SET Selected = 1
  END
  ELSE IF @HostPlatform = 'Linux'
  BEGIN
   UPDATE @Jobs
   SET Selected = 1
   WHERE CommandTSQL IS NOT NULL
  END

  WHILE EXISTS (SELECT * FROM @Jobs WHERE Completed = 0 AND Selected = 1)
  BEGIN
    SELECT @CurrentJobID = JobID,
           @CurrentJobName = [Name],
           @CurrentCommandTSQL = CommandTSQL,
           @CurrentCommandCmdExec = CommandCmdExec,
           @CurrentDatabaseName = DatabaseName,
           @CurrentOutputFileNamePart01 = OutputFileNamePart01,
           @CurrentOutputFileNamePart02 = OutputFileNamePart02
    FROM @Jobs
    WHERE Completed = 0
    AND Selected = 1
    ORDER BY JobID ASC

    IF @CurrentCommandTSQL IS NOT NULL AND @AmazonRDS = 1
    BEGIN
      SET @CurrentJobStepSubSystem = 'TSQL'
      SET @CurrentJobStepCommand = @CurrentCommandTSQL
      SET @CurrentJobStepDatabaseName = @CurrentDatabaseName
    END
    ELSE IF @CurrentCommandTSQL IS NOT NULL AND SERVERPROPERTY('EngineEdition') = 8
    BEGIN
      SET @CurrentJobStepSubSystem = 'TSQL'
      SET @CurrentJobStepCommand = @CurrentCommandTSQL
      SET @CurrentJobStepDatabaseName = @CurrentDatabaseName
    END
    ELSE IF @CurrentCommandTSQL IS NOT NULL AND @HostPlatform = 'Linux'
    BEGIN
      SET @CurrentJobStepSubSystem = 'TSQL'
      SET @CurrentJobStepCommand = @CurrentCommandTSQL
      SET @CurrentJobStepDatabaseName = @CurrentDatabaseName
    END
    ELSE IF @CurrentCommandTSQL IS NOT NULL AND @HostPlatform = 'Windows' AND @Version >= 11
    BEGIN
      SET @CurrentJobStepSubSystem = 'TSQL'
      SET @CurrentJobStepCommand = @CurrentCommandTSQL
      SET @CurrentJobStepDatabaseName = @CurrentDatabaseName
    END
    ELSE IF @CurrentCommandTSQL IS NOT NULL AND @HostPlatform = 'Windows' AND @Version < 11
    BEGIN
      SET @CurrentJobStepSubSystem = 'CMDEXEC'
      SET @CurrentJobStepCommand = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @CurrentDatabaseName + ' -Q "' + REPLACE(@CurrentCommandTSQL,(CHAR(13) + CHAR(10)),' ') + '" -b'
      SET @CurrentJobStepDatabaseName = NULL
    END
    ELSE IF @CurrentCommandCmdExec IS NOT NULL AND @HostPlatform = 'Windows'
    BEGIN
      SET @CurrentJobStepSubSystem = 'CMDEXEC'
      SET @CurrentJobStepCommand = @CurrentCommandCmdExec
      SET @CurrentJobStepDatabaseName = NULL
    END

    IF @AmazonRDS = 0 AND SERVERPROPERTY('EngineEdition') <> 8
    BEGIN
      SET @CurrentOutputFileName = COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + @DirectorySeparator + ISNULL(CASE WHEN @TokenJobName IS NULL THEN @CurrentOutputFileNamePart01 END + '_','') + ISNULL(CASE WHEN @TokenJobName IS NULL THEN @CurrentOutputFileNamePart02 END + '_','') + ISNULL(@TokenJobName,@TokenJobID) + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
      IF LEN(@CurrentOutputFileName) > 200 SET @CurrentOutputFileName = COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + @DirectorySeparator + ISNULL(CASE WHEN @TokenJobName IS NULL THEN @CurrentOutputFileNamePart01 END + '_','') + ISNULL(@TokenJobName,@TokenJobID) + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
      IF LEN(@CurrentOutputFileName) > 200 SET @CurrentOutputFileName = COALESCE(@OutputFileDirectory,@TokenLogDirectory,@LogDirectory) + @DirectorySeparator + ISNULL(@TokenJobName,@TokenJobID) + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
      IF LEN(@CurrentOutputFileName) > 200 SET @CurrentOutputFileName = NULL
    END

    IF @CurrentJobStepSubSystem IS NOT NULL AND @CurrentJobStepCommand IS NOT NULL AND NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @CurrentJobName)
    BEGIN
      EXECUTE msdb.dbo.sp_add_job @job_name = @CurrentJobName, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
      EXECUTE msdb.dbo.sp_add_jobstep @job_name = @CurrentJobName, @step_name = @CurrentJobName, @subsystem = @CurrentJobStepSubSystem, @command = @CurrentJobStepCommand, @output_file_name = @CurrentOutputFileName, @database_name = @CurrentJobStepDatabaseName
      EXECUTE msdb.dbo.sp_add_jobserver @job_name = @CurrentJobName
    END

    UPDATE Jobs
    SET Completed = 1
    FROM @Jobs Jobs
    WHERE JobID = @CurrentJobID

    SET @CurrentJobID = NULL
    SET @CurrentJobName = NULL
    SET @CurrentCommandTSQL = NULL
    SET @CurrentCommandCmdExec = NULL
    SET @CurrentDatabaseName = NULL
    SET @CurrentOutputFileNamePart01 = NULL
    SET @CurrentOutputFileNamePart02 = NULL
    SET @CurrentJobStepCommand = NULL
    SET @CurrentJobStepSubSystem = NULL
    SET @CurrentJobStepDatabaseName = NULL
    SET @CurrentOutputFileName = NULL

  END

END
GO

a/*

SQL Server Maintenance Solution - SQL Server 2008, SQL Server 2008 R2, SQL Server 2012, SQL Server 2014, SQL Server 2016, SQL Server 2017, SQL Server 2019, and SQL Server 2022

Backup: https://ola.hallengren.com/sql-server-backup.html
Integrity Check: https://ola.hallengren.com/sql-server-integrity-check.html
Index and Statistics Maintenance: https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html

License: https://ola.hallengren.com/license.html

GitHub: https://github.com/olahallengren/sql-server-maintenance-solution

Version: 2025-08-23 17:25:24

You can contact me by e-mail at ola@hallengren.com.

Ola Hallengren
https://ola.hallengren.com

*/

USE [master] -- Specify the database in which the objects will be created.

SET NOCOUNT ON

DECLARE @CreateJobs nvarchar(max)          = 'Y'         -- Specify whether jobs should be created.
DECLARE @BackupDirectory nvarchar(max)     = NULL        -- Specify the backup root directory. If no directory is specified, the default backup directory is used.
DECLARE @BackupURL nvarchar(max)           = NULL        -- Specify the backup root URL.
DECLARE @CleanupTime int                   = NULL        -- Time in hours, after which backup files are deleted. If no time is specified, then no backup files are deleted.
DECLARE @OutputFileDirectory nvarchar(max) = NULL        -- Specify the output file directory. If no directory is specified, then the SQL Server error log directory is used.
DECLARE @LogToTable nvarchar(max)          = 'Y'         -- Log commands to a table.

DECLARE @ErrorMessage nvarchar(max)

IF IS_SRVROLEMEMBER('sysadmin') = 0 AND NOT (EXISTS (SELECT * FROM sys.databases WHERE [name] = 'rdsadmin') AND SUSER_SNAME(0x01) = 'rdsa')
BEGIN
  SET @ErrorMessage = 'You need to be a member of the SysAdmin server role to install the SQL Server Maintenance Solution.'
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
END

IF NOT (SELECT [compatibility_level] FROM sys.databases WHERE [name] = DB_NAME()) >= 90
BEGIN
  SET @ErrorMessage = 'The database ' + QUOTENAME(DB_NAME()) + ' has to be in compatibility level 90 or higher.'
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
END

IF @BackupDirectory IS NOT NULL AND @BackupURL IS NOT NULL
BEGIN
  SET @ErrorMessage = 'Only one of the variables @BackupDirectory and @BackupURL can be set.'
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
END

IF @BackupURL IS NOT NULL AND @CleanupTime IS NOT NULL
BEGIN
  SET @ErrorMessage = 'The variable @CleanupTime is not supported with backup to URL.'
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
END

IF OBJECT_ID('tempdb..#Config') IS NOT NULL DROP TABLE #Config

CREATE TABLE #Config ([Name] nvarchar(max),
                      [Value] nvarchar(max))

INSERT INTO #Config ([Name], [Value]) VALUES('CreateJobs', @CreateJobs)
INSERT INTO #Config ([Name], [Value]) VALUES('BackupDirectory', @BackupDirectory)
INSERT INTO #Config ([Name], [Value]) VALUES('BackupURL', @BackupURL)
INSERT INTO #Config ([Name], [Value]) VALUES('CleanupTime', @CleanupTime)
INSERT INTO #Config ([Name], [Value]) VALUES('OutputFileDirectory', @OutputFileDirectory)
INSERT INTO #Config ([Name], [Value]) VALUES('LogToTable', @LogToTable)
INSERT INTO #Config ([Name], [Value]) VALUES('DatabaseName', DB_NAME())

GO


DECLARE @job_id uniqueidentifier
DECLARE @step_id int
DECLARE @command nvarchar(max)
DECLARE @AmazonRDS bit = CASE WHEN SERVERPROPERTY('EngineEdition') IN (5, 8) THEN 0 WHEN EXISTS (SELECT * FROM sys.databases WHERE [name] = 'rdsadmin') AND SUSER_SNAME(0x01) = 'rdsa' THEN 1 ELSE 0 END

IF @AmazonRDS = 0
BEGIN

  DECLARE JobCursor CURSOR FAST_FORWARD FOR SELECT job_id, step_id, command FROM msdb.dbo.sysjobsteps WHERE command LIKE '%DatabaseBackup%@CheckSum%' COLLATE SQL_Latin1_General_CP1_CS_AS

  OPEN JobCursor

  FETCH JobCursor INTO @job_id, @step_id, @command

  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @command = REPLACE(@command, '@CheckSum', '@Checksum')

    EXECUTE msdb.dbo.sp_update_jobstep @job_id = @job_id, @step_id = @step_id, @command = @command

    FETCH NEXT FROM JobCursor INTO @job_id, @step_id, @command
  END

  CLOSE JobCursor

  DEALLOCATE JobCursor
END


GO
