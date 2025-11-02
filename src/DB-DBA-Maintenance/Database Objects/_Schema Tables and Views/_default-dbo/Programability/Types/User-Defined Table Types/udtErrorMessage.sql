CREATE TYPE [dbo].[udtErrorMessage] AS TABLE
(
    [Message] NVARCHAR(MAX) NOT NULL,
    Severity  INT           NOT NULL,
    [State]   INT           NULL
);
