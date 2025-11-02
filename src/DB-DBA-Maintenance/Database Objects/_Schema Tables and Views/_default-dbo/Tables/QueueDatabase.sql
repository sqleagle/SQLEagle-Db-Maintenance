CREATE TABLE [dbo].[QueueDatabase]
(
    [QueueID]           [INT]          NOT NULL,
    [DatabaseName]      [sysname]      NOT NULL,
    [DatabaseOrder]     [INT]          NULL,
    [DatabaseStartTime] [DATETIME2](7) NULL,
    [DatabaseEndTime]   [DATETIME2](7) NULL,
    [SessionID]         [SMALLINT]     NULL,
    [RequestID]         [INT]          NULL,
    [RequestStartTime]  [DATETIME]     NULL,
    CONSTRAINT [PK_QueueDatabase]
        PRIMARY KEY CLUSTERED (
                                  [QueueID] ASC,
                                  [DatabaseName] ASC
                              )
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON
             )
);

GO
ALTER TABLE [dbo].[QueueDatabase]
ADD CONSTRAINT [FK_QueueDatabase_Queue]
    FOREIGN KEY ([QueueID])
    REFERENCES [dbo].[Queue] ([QueueID]);
GO

ALTER TABLE [dbo].[QueueDatabase] CHECK CONSTRAINT [FK_QueueDatabase_Queue];
