CREATE TABLE [dbo].[Queue]
(
    [QueueID]          [INT] IDENTITY(1, 1) NOT NULL,
    [SchemaName]       [sysname]            NOT NULL,
    [ObjectName]       [sysname]            NOT NULL,
    [Parameters]       [NVARCHAR](MAX)      NOT NULL,
    [QueueStartTime]   [DATETIME2](7)       NULL,
    [SessionID]        [SMALLINT]           NULL,
    [RequestID]        [INT]                NULL,
    [RequestStartTime] [DATETIME]           NULL,
    CONSTRAINT [PK_Queue]
        PRIMARY KEY CLUSTERED ([QueueID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON
             )
);
