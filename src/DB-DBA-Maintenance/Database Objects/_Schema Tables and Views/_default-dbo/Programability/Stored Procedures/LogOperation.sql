CREATE PROCEDURE [dbo].[uspLogOperation]
    @DatabaseName nvarchar(max),
    @SchemaName nvarchar(max),
    @ObjectName nvarchar(max),
    @ObjectType nvarchar(max),
    @IndexName nvarchar(max),
    @IndexType int,
    @StatisticsName nvarchar(max),
    @PartitionNumber int,
    @ExtendedInfo xml,
    @CommandType nvarchar(max),
    @Command nvarchar(max),
    @StartTime datetime2,
    @EndTime datetime2 = NULL,
    @ErrorNumber int = NULL,
    @ErrorMessage nvarchar(max) = NULL,
    @ID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartTime IS NOT NULL AND @EndTime IS NULL
    BEGIN
        -- Log start of operation
        INSERT INTO dbo.CommandLog
        (
            DatabaseName,
            SchemaName,
            ObjectName,
            ObjectType,
            IndexName,
            IndexType,
            StatisticsName,
            PartitionNumber,
            ExtendedInfo,
            CommandType,
            Command,
            StartTime
        )
        VALUES
        (@DatabaseName, @SchemaName, @ObjectName, @ObjectType, @IndexName, @IndexType, @StatisticsName, @PartitionNumber,
         @ExtendedInfo, @CommandType, @Command, @StartTime);

        SET @ID = SCOPE_IDENTITY()
    END
    ELSE IF @StartTime IS NOT NULL AND @EndTime IS NOT NULL
    BEGIN
        -- Update existing log entry with completion info
        UPDATE dbo.CommandLog
        SET EndTime = @EndTime,
            ErrorNumber = @ErrorNumber,
            ErrorMessage = @ErrorMessage
        WHERE ID = @ID
    END
END