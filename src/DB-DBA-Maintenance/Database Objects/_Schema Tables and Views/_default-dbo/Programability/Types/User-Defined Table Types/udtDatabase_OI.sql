CREATE TYPE [dbo].[udtDatabase_OI] AS TABLE
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
);
