CREATE PROCEDURE [dbo].[uspValidateParameters]
    @DatabaseName NVARCHAR(MAX),
    @LogToTable NVARCHAR(MAX),
    @Execute NVARCHAR(MAX),
    @Errors udtErrorMessage READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Check core requirements
    --IF NOT (SELECT [compatibility_level] FROM sys.databases WHERE [name] = DB_NAME()) >= 90
    IF NOT
       (
           SELECT [compatibility_level]
           FROM sys.databases
           WHERE [name] = @DatabaseName
       ) >= 90
    BEGIN
        --INSERT INTO @Errors ([Message], Severity, [State])
        --SELECT 'The database ' + QUOTENAME(DB_NAME()) + ' has to be in compatibility level 90 or higher.', 16, 1
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The database ' + @DatabaseName + ' has to be in compatibility level 90 or higher.',
               16,
               1;
    END;

    IF NOT
       (
           SELECT uses_ansi_nulls FROM sys.sql_modules WHERE [object_id] = @@PROCID
       ) = 1
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'ANSI_NULLS has to be set to ON for the stored procedure.',
               16,
               1;
    END;

    IF NOT
       (
           SELECT uses_quoted_identifier
           FROM sys.sql_modules
           WHERE [object_id] = @@PROCID
       ) = 1
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'QUOTED_IDENTIFIER has to be set to ON for the stored procedure.',
               16,
               1;
    END;

    -- Check CommandLog table existence
    IF @LogToTable = 'Y'
       AND NOT EXISTS
    (
        SELECT *
        FROM sys.objects objects
            INNER JOIN sys.schemas schemas
                ON objects.[schema_id] = schemas.[schema_id]
        WHERE objects.[type] = 'U'
              AND schemas.[name] = 'dbo'
              AND objects.[name] = 'CommandLog'
    )
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The table CommandLog is missing. Download https://ola.hallengren.com/scripts/CommandLog.sql.',
               16,
               1;
    END;

    -- Validate common parameters
    IF @LogToTable NOT IN ( 'Y', 'N' )
       OR @LogToTable IS NULL
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The value for the parameter @LogToTable is not supported.',
               16,
               1;
    END;

    IF @Execute NOT IN ( 'Y', 'N' )
       OR @Execute IS NULL
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The value for the parameter @Execute is not supported.',
               16,
               1;
    END;

    IF @@TRANCOUNT <> 0
    BEGIN
        INSERT INTO @Errors
        (
            [Message],
            Severity,
            [State]
        )
        SELECT 'The transaction count is not 0.',
               16,
               1;
    END;
END;