CREATE PROCEDURE [dbo].[uspErrorHandling]
@Errors udtErrorMessage READONLY,
@EmptyLine nvarchar(max),
@ReturnCode int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentMessage nvarchar(max)
    DECLARE @CurrentSeverity int
    DECLARE @CurrentState int

    -- Declare cursor for reading errors
    DECLARE ErrorCursor CURSOR FAST_FORWARD FOR 
    SELECT [Message], Severity, [State] 
    FROM @Errors 
    ORDER BY [ID] ASC

    OPEN ErrorCursor

    FETCH ErrorCursor INTO @CurrentMessage, @CurrentSeverity, @CurrentState

    WHILE @@FETCH_STATUS = 0
    BEGIN
    RAISERROR('%s', @CurrentSeverity, @CurrentState, @CurrentMessage) WITH NOWAIT
        RAISERROR(@EmptyLine, 10, 1) WITH NOWAIT

        FETCH NEXT FROM ErrorCursor INTO @CurrentMessage, @CurrentSeverity, @CurrentState
    END

    CLOSE ErrorCursor
    DEALLOCATE ErrorCursor

    IF EXISTS (SELECT * FROM @Errors WHERE Severity >= 16)
    BEGIN
        SET @ReturnCode = 50000
        RETURN @ReturnCode
    END

    SET @ReturnCode = 0
END