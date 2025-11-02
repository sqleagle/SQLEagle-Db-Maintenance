CREATE TYPE [dbo].[udtDatabase_DB] AS TABLE
(
    ID                        INT IDENTITY  NOT NULL,
    DatabaseName              NVARCHAR(MAX) NOT NULL,
    DatabaseNameFS            NVARCHAR(MAX) NULL,
    DatabaseType              NVARCHAR(MAX) NOT NULL,
    AvailabilityGroup         BIT           NULL,
    StartPosition             INT           NOT NULL
        DEFAULT (0),
    DatabaseSize              BIGINT        NOT NULL
        DEFAULT (0),
    LogSizeSinceLastLogBackup FLOAT         NOT NULL
        DEFAULT (0),
    [Order]                   INT           NOT NULL
        DEFAULT (0),
    Selected                  BIT           NOT NULL
        DEFAULT (0),
    Completed                 BIT           NOT NULL
        DEFAULT (0),
    PRIMARY KEY (
                    Selected,
                    Completed,
                    [Order],
                    id
                )
);