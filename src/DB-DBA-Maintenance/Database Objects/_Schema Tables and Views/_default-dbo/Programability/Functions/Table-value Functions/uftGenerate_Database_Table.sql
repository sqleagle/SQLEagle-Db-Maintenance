CREATE FUNCTION [dbo].[uftGenerate_Database_Table]
(
	@Databases       NVARCHAR(MAX) = NULL,
    @StringDelimiter NVARCHAR(MAX) = ',' ,
    @Version         INT           = 15
    --@SelectedDatabases TABLE (DatabaseName nvarchar(max),
    --                                DatabaseType nvarchar(max),
    --                                AvailabilityGroup nvarchar(max),
    --                                StartPosition int,
    --                                Selected bit),
    --@tmpAvailabilityGroups TABLE (AvailabilityGroupName nvarchar(max),
    --                                    Selected bit),
    --@tmpDatabasesAvailabilityGroups TABLE (DatabaseName nvarchar(max),
    --                                             AvailabilityGroupName nvarchar(max))
    --@DatabaseOrder nvarchar(max) = NULL
)
RETURNS @DatabaseTable TABLE
(
    ID                INT IDENTITY  NOT NULL,
    DatabaseName      NVARCHAR(MAX) NOT NULL,
    DatabaseType      NVARCHAR(MAX) NOT NULL,
    AvailabilityGroup BIT           NOT NULL
        DEFAULT (0),
    StartPosition     INT           NOT NULL
        DEFAULT (0),
    DatabaseSize      BIGINT        NOT NULL,
    [Order]           INT           NOT NULL
        DEFAULT (0),
    Selected          BIT           NOT NULL
        DEFAULT (0),
    Completed         BIT           NOT NULL 
        DEFAULT (0),
    PRIMARY KEY (
                    Selected,
                    Completed,
                    [Order],
                    id
                )
)
AS
BEGIN

    DECLARE @Errors TABLE
    (
        ID        INT IDENTITY PRIMARY KEY,
        [Message] NVARCHAR(MAX) NOT NULL,
        Severity  INT           NOT NULL,
        [State]   INT           NULL
    );

    DECLARE @SelectedDatabases TABLE
    (
        DatabaseName NVARCHAR(MAX),
        DatabaseType NVARCHAR(MAX),
        AvailabilityGroup NVARCHAR(MAX),
        StartPosition INT,
        Selected BIT
    );

    DECLARE @tmpAvailabilityGroups TABLE
    (
        AvailabilityGroupName NVARCHAR(MAX),
        Selected BIT
    );

    DECLARE @tmpDatabasesAvailabilityGroups TABLE
    (
        DatabaseName NVARCHAR(MAX),
        AvailabilityGroupName NVARCHAR(MAX)
    );

    SET @Databases = REPLACE(@Databases, CHAR(10), '')
    SET @Databases = REPLACE(@Databases, CHAR(13), '')

    WHILE CHARINDEX(@StringDelimiter + ' ', @Databases) > 0 SET @Databases = REPLACE(@Databases, @StringDelimiter + ' ', @StringDelimiter)
    WHILE CHARINDEX(' ' + @StringDelimiter, @Databases) > 0 SET @Databases = REPLACE(@Databases, ' ' + @StringDelimiter, @StringDelimiter)

    SET @Databases = LTRIM(RTRIM(@Databases));

    WITH Databases1 (StartPosition, EndPosition, DatabaseItem) AS
    (
    SELECT 1 AS StartPosition,
            ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, 1), 0), LEN(@Databases) + 1) AS EndPosition,
            SUBSTRING(@Databases, 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, 1), 0), LEN(@Databases) + 1) - 1) AS DatabaseItem
    WHERE @Databases IS NOT NULL
    UNION ALL
    SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
            ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) AS EndPosition,
            SUBSTRING(@Databases, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@StringDelimiter, @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) - EndPosition - 1) AS DatabaseItem
    FROM Databases1
    WHERE EndPosition < LEN(@Databases) + 1
    ),
    Databases2 (DatabaseItem, StartPosition, Selected) AS
    (
    SELECT CASE WHEN DatabaseItem LIKE '-%' THEN RIGHT(DatabaseItem,LEN(DatabaseItem) - 1) ELSE DatabaseItem END AS DatabaseItem,
            StartPosition,
            CASE WHEN DatabaseItem LIKE '-%' THEN 0 ELSE 1 END AS Selected
    FROM Databases1
    ),
    Databases3 (DatabaseItem, DatabaseType, AvailabilityGroup, StartPosition, Selected) AS
    (
    SELECT CASE WHEN DatabaseItem IN('ALL_DATABASES','SYSTEM_DATABASES','USER_DATABASES','AVAILABILITY_GROUP_DATABASES') THEN '%' ELSE DatabaseItem END AS DatabaseItem,
            CASE WHEN DatabaseItem = 'SYSTEM_DATABASES' THEN 'S' WHEN DatabaseItem = 'USER_DATABASES' THEN 'U' ELSE NULL END AS DatabaseType,
            CASE WHEN DatabaseItem = 'AVAILABILITY_GROUP_DATABASES' THEN 1 ELSE NULL END AvailabilityGroup,
            StartPosition,
            Selected
    FROM Databases2
    ),
    Databases4 (DatabaseName, DatabaseType, AvailabilityGroup, StartPosition, Selected) AS
    (
    SELECT CASE WHEN LEFT(DatabaseItem,1) = '[' AND RIGHT(DatabaseItem,1) = ']' THEN PARSENAME(DatabaseItem,1) ELSE DatabaseItem END AS DatabaseItem,
            DatabaseType,
            AvailabilityGroup,
            StartPosition,
            Selected
    FROM Databases3
    )
    INSERT INTO @SelectedDatabases (DatabaseName, DatabaseType, AvailabilityGroup, StartPosition, Selected)
    SELECT DatabaseName,
            DatabaseType,
            AvailabilityGroup,
            StartPosition,
            Selected
    FROM Databases4
    OPTION (MAXRECURSION 0)

    IF @Version >= 11 AND SERVERPROPERTY('IsHadrEnabled') = 1
    BEGIN
    INSERT INTO @tmpAvailabilityGroups (AvailabilityGroupName, Selected)
    SELECT name AS AvailabilityGroupName,
            0 AS Selected
    FROM sys.availability_groups

    INSERT INTO @tmpDatabasesAvailabilityGroups (DatabaseName, AvailabilityGroupName)
    SELECT databases.name,
            availability_groups.name
    FROM sys.databases databases
    INNER JOIN sys.availability_replicas availability_replicas ON databases.replica_id = availability_replicas.replica_id
    INNER JOIN sys.availability_groups availability_groups ON availability_replicas.group_id = availability_groups.group_id
    END

    INSERT INTO @DatabaseTable(DatabaseName, DatabaseType, AvailabilityGroup, [Order], Selected, Completed)
    SELECT [name] AS DatabaseName,
            CASE WHEN name IN('master','msdb','model') OR is_distributor = 1 THEN 'S' ELSE 'U' END AS DatabaseType,
            NULL AS AvailabilityGroup,
            0 AS [Order],
            0 AS Selected,
            0 AS Completed
    FROM sys.databases
    WHERE [name] <> 'tempdb'
    AND source_database_id IS NULL
    ORDER BY [name] ASC

    UPDATE tmpDatabases
    SET AvailabilityGroup = CASE WHEN EXISTS (SELECT * FROM @tmpDatabasesAvailabilityGroups WHERE DatabaseName = tmpDatabases.DatabaseName) THEN 1 ELSE 0 END
    FROM @DatabaseTable tmpDatabases

    UPDATE tmpDatabases
    SET tmpDatabases.Selected = SelectedDatabases.Selected
    FROM @DatabaseTable tmpDatabases
    INNER JOIN @SelectedDatabases SelectedDatabases
    ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
    AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
    AND (tmpDatabases.AvailabilityGroup = SelectedDatabases.AvailabilityGroup OR SelectedDatabases.AvailabilityGroup IS NULL)
    WHERE SelectedDatabases.Selected = 1

    UPDATE tmpDatabases
    SET tmpDatabases.Selected = SelectedDatabases.Selected
    FROM @DatabaseTable tmpDatabases
    INNER JOIN @SelectedDatabases SelectedDatabases
    ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
    AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
    AND (tmpDatabases.AvailabilityGroup = SelectedDatabases.AvailabilityGroup OR SelectedDatabases.AvailabilityGroup IS NULL)
    WHERE SelectedDatabases.Selected = 0

    UPDATE tmpDatabases
    SET tmpDatabases.StartPosition = SelectedDatabases2.StartPosition
    FROM @DatabaseTable tmpDatabases
    INNER JOIN (SELECT tmpDatabases.DatabaseName, MIN(SelectedDatabases.StartPosition) AS StartPosition
                FROM @DatabaseTable tmpDatabases
                INNER JOIN @SelectedDatabases SelectedDatabases
                ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
                AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
                AND (tmpDatabases.AvailabilityGroup = SelectedDatabases.AvailabilityGroup OR SelectedDatabases.AvailabilityGroup IS NULL)
                WHERE SelectedDatabases.Selected = 1
                GROUP BY tmpDatabases.DatabaseName) SelectedDatabases2
    ON tmpDatabases.DatabaseName = SelectedDatabases2.DatabaseName

    IF @Databases IS NOT NULL AND (NOT EXISTS(SELECT * FROM @SelectedDatabases) OR EXISTS(SELECT * FROM @SelectedDatabases WHERE DatabaseName IS NULL OR DATALENGTH(DatabaseName) = 0))
    BEGIN
        INSERT INTO @Errors ([Message], Severity, [State])
        SELECT 'The value for the parameter @Databases is not supported.', 16, 1
    END

    RETURN;

END
