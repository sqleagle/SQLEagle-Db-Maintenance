CREATE PROCEDURE [dbo].uspCommandExecute
    @DatabaseContext NVARCHAR(MAX),
    @Command NVARCHAR(MAX),
    @CommandType NVARCHAR(MAX),
    @Mode INT,
    --@Comment NVARCHAR(MAX) = NULL,
    @DatabaseName NVARCHAR(MAX) = NULL,
    @SchemaName NVARCHAR(MAX) = NULL,
    @ObjectName NVARCHAR(MAX) = NULL,
    @ObjectType NVARCHAR(MAX) = NULL,
    @IndexName NVARCHAR(MAX) = NULL,
    @IndexType INT = NULL,
    @StatisticsName NVARCHAR(MAX) = NULL,
    @PartitionNumber INT = NULL,
    @ExtendedInfo XML = NULL,
    @LockMessageSeverity INT = 16,
    @ExecuteAsUser NVARCHAR(MAX) = NULL,
    @LogToTable NVARCHAR(MAX),
    @Execute NVARCHAR(MAX)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME2;
    DECLARE @EndTime DATETIME2;
    DECLARE @ID INT;
    DECLARE @Error INT = 0;
    DECLARE @ReturnCode INT = 0;
    DECLARE @EmptyLine NVARCHAR(MAX) = CHAR(9);
    DECLARE @StartMessage NVARCHAR(MAX);
    DECLARE @EndMessage NVARCHAR(MAX);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ErrorMessageOriginal NVARCHAR(MAX);
    DECLARE @Severity INT;
    DECLARE @sp_executesql NVARCHAR(MAX);
    DECLARE @RevertCommand NVARCHAR(MAX);

    -- Table variable for error handling
    DECLARE @Errors TABLE
    (
        ID INT IDENTITY PRIMARY KEY,
        [Message] NVARCHAR(MAX) NOT NULL,
        Severity INT NOT NULL,
        [State] INT
    );

    -- Validate parameters
    EXEC dbo.uspValidateParameters @DatabaseName = @DatabaseName,
                                   @LogToTable = @LogToTable,
                                   @Execute = @Execute,
                                   @Errors = @Errors;

    -- Additional specific validations
    IF @DatabaseContext IS NULL
       OR NOT EXISTS
    (
        SELECT *
        FROM sys.databases
        WHERE name = @DatabaseContext
    )
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The value for the parameter @DatabaseContext is not supported.',
               16,
               1;
    END;

    IF @Command IS NULL
       OR @Command = ''
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The value for the parameter @Command is not supported.',
               16,
               1;
    END;

    -- Handle any validation errors
    EXEC dbo.uspErrorHandling @Errors = @Errors,
                              @EmptyLine = @EmptyLine,
                              @ReturnCode = @ReturnCode OUTPUT;

    IF @ReturnCode <> 0
        GOTO ReturnCode;

    -- Set up execution context
    SET @sp_executesql = QUOTENAME(@DatabaseContext) + N'.sys.sp_executesql';
    SET @StartTime = SYSDATETIME();

    IF @ExecuteAsUser IS NOT NULL
    BEGIN
        SET @Command
            = 'EXECUTE AS USER = ''' + REPLACE(@ExecuteAsUser, '''', '''''') + '''; ' + @Command + '; REVERT;';
        SET @RevertCommand = N'REVERT';
    END;

    -- Log operation start
    EXEC dbo.uspLogOperation @DatabaseName = @DatabaseName,
                             @SchemaName = @SchemaName,
                             @ObjectName = @ObjectName,
                             @ObjectType = @ObjectType,
                             @IndexName = @IndexName,
                             @IndexType = @IndexType,
                             @StatisticsName = @StatisticsName,
                             @PartitionNumber = @PartitionNumber,
                             @ExtendedInfo = @ExtendedInfo,
                             @CommandType = @CommandType,
                             @Command = @Command,
                             @StartTime = @StartTime,
                             @ID = @ID OUTPUT;

    -- Execute command based on mode
    IF @Mode = 1
       AND @Execute = 'Y'
    BEGIN
        EXECUTE @sp_executesql @stmt = @Command;
        SET @Error = @@ERROR;
        SET @ReturnCode = @Error;
    END;

    IF @Mode = 2
       AND @Execute = 'Y'
    BEGIN
        BEGIN TRY
            EXECUTE @sp_executesql @stmt = @Command;
        END TRY
        BEGIN CATCH
            SET @Error = ERROR_NUMBER();
            SET @ErrorMessageOriginal = ERROR_MESSAGE();

            SET @ErrorMessage = N'Msg ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N', ' + ISNULL(ERROR_MESSAGE(), '');
            SET @Severity = CASE
                                WHEN ERROR_NUMBER() IN ( 1205, 1222 ) THEN
                                    @LockMessageSeverity
                                ELSE
                                    16
                            END;
            RAISERROR('%s', @Severity, 1, @ErrorMessage) WITH NOWAIT;

            IF NOT (
                       ERROR_NUMBER() IN ( 1205, 1222 )
                       AND @LockMessageSeverity = 10
                   )
            BEGIN
                SET @ReturnCode = ERROR_NUMBER();
            END;

            IF @ExecuteAsUser IS NOT NULL
            BEGIN
                EXECUTE @sp_executesql @RevertCommand;
            END;
        END CATCH;
    END;

    -- Log operation completion
    SET @EndTime = SYSDATETIME();

    -- if no error message captured, set to empty
    DECLARE @pErrorNumber INT = CASE
                                    WHEN @Execute = 'N' THEN
                                        NULL
                                    ELSE
                                        @Error
                                END;

    EXEC dbo.uspLogOperation @DatabaseName = @DatabaseName,
                             @SchemaName = @SchemaName,
                             @ObjectName = @ObjectName,
                             @ObjectType = @ObjectType,
                             @IndexName = @IndexName,
                             @IndexType = @IndexType,
                             @StatisticsName = @StatisticsName,
                             @PartitionNumber = @PartitionNumber,
                             @ExtendedInfo = @ExtendedInfo,
                             @CommandType = @CommandType,
                             @Command = @Command,
                             @StartTime = @StartTime,
                             @EndTime = @EndTime,
                             @ErrorNumber = @pErrorNumber,
                             @ErrorMessage = @ErrorMessageOriginal,
                             @ID = @ID;

    -- Output completion messages
    SET @EndMessage = N'Outcome: ' + CASE
                                         WHEN @Execute = 'N' THEN
                                             'Not Executed'
                                         WHEN @Error = 0 THEN
                                             'Succeeded'
                                         ELSE
                                             'Failed'
                                     END;
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT;

    SET @EndMessage
        = N'Duration: ' + CASE
                              WHEN (DATEDIFF(SECOND, @StartTime, @EndTime) / (24 * 3600)) > 0 THEN
                                  CAST((DATEDIFF(SECOND, @StartTime, @EndTime) / (24 * 3600)) AS NVARCHAR) + '.'
                              ELSE
                                  ''
                          END
          + CONVERT(NVARCHAR, DATEADD(SECOND, DATEDIFF(SECOND, @StartTime, @EndTime), '1900-01-01'), 108);
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT;

    SET @EndMessage = N'Date and time: ' + CONVERT(NVARCHAR, @EndTime, 120);
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT;

    RAISERROR(@EmptyLine, 10, 1) WITH NOWAIT;

    ReturnCode:
    IF @ReturnCode <> 0
    BEGIN
        RETURN @ReturnCode;
    END;

----------------------------------------------------------------------------------------------------

END;