CREATE TABLE stg_ps4 (
    Game          NVARCHAR(300),
    Year          NVARCHAR(10),
    Genre         NVARCHAR(100),
    Publisher     NVARCHAR(200),
    North_America NVARCHAR(20),
    Europe        NVARCHAR(20),
    Japan         NVARCHAR(20),
    Rest_of_World NVARCHAR(20),
    Global        NVARCHAR(20)
);

CREATE TABLE stg_xbox (
    Pos           NVARCHAR(10),
    Game          NVARCHAR(300),
    Year          NVARCHAR(10),
    Genre         NVARCHAR(100),
    Publisher     NVARCHAR(200),
    North_America NVARCHAR(20),
    Europe        NVARCHAR(20),
    Japan         NVARCHAR(20),
    Rest_of_World NVARCHAR(20),
    Global        NVARCHAR(20)
);

CREATE TABLE stg_historical (
    Name            NVARCHAR(300),
    Platform        NVARCHAR(50),
    Year_of_Release NVARCHAR(10),
    Genre           NVARCHAR(100),
    Publisher       NVARCHAR(200),
    NA_Sales        NVARCHAR(20),
    EU_Sales        NVARCHAR(20),
    JP_Sales        NVARCHAR(20),
    Other_Sales     NVARCHAR(20),
    Global_Sales    NVARCHAR(20),
    Critic_Score    NVARCHAR(10),
    Critic_Count    NVARCHAR(10),
    User_Score      NVARCHAR(10),
    User_Count      NVARCHAR(10),
    Developer       NVARCHAR(200),
    Rating          NVARCHAR(20)
);
GO

-- ─── BULK INSERT con separador | ─────────────────────────────
BULK INSERT stg_ps4
FROM 'C:\Users\Asses\Downloads\ps4_clean.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    MAXERRORS       = 10,
    TABLOCK
);
GO

BULK INSERT stg_xbox
FROM 'C:\Users\Asses\Downloads\xbox_clean.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    MAXERRORS       = 10,
    TABLOCK
);
GO

BULK INSERT stg_historical
FROM 'C:\Users\Asses\Downloads\hist_clean.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    MAXERRORS       = 10,
    TABLOCK
);
GO

-- ══════════════════════════════════════════════════
-- CREAR DIMENSIONES
-- ══════════════════════════════════════════════════
CREATE TABLE dim_platform (
    platform_id  INT IDENTITY(1,1) PRIMARY KEY,
    Platform     NVARCHAR(50) NOT NULL
);

CREATE TABLE dim_genre (
    genre_id  INT IDENTITY(1,1) PRIMARY KEY,
    Genre     NVARCHAR(100) NOT NULL
);

CREATE TABLE dim_publisher (
    publisher_id  INT IDENTITY(1,1) PRIMARY KEY,
    Publisher     NVARCHAR(200) NOT NULL
);

CREATE TABLE dim_time (
    time_id  INT IDENTITY(1,1) PRIMARY KEY,
    year     INT NOT NULL,
    decade   INT NOT NULL,
    era      NVARCHAR(50) NOT NULL
);

CREATE TABLE dim_game (
    game_id    INT IDENTITY(1,1) PRIMARY KEY,
    Name       NVARCHAR(300) NOT NULL,
    Developer  NVARCHAR(200),
    Rating     NVARCHAR(20)
);

CREATE TABLE fact_sales (
    sale_id       INT IDENTITY(1,1) PRIMARY KEY,
    game_id       INT REFERENCES dim_game(game_id),
    platform_id   INT REFERENCES dim_platform(platform_id),
    genre_id      INT REFERENCES dim_genre(genre_id),
    publisher_id  INT REFERENCES dim_publisher(publisher_id),
    time_id       INT REFERENCES dim_time(time_id),
    NA_Sales      FLOAT,
    EU_Sales      FLOAT,
    JP_Sales      FLOAT,
    Other_Sales   FLOAT,
    Global_Sales  FLOAT,
    Critic_Score  FLOAT,
    source        NVARCHAR(50)
);
GO

-- ══════════════════════════════════════════════════
-- POBLAR dim_platform
-- ══════════════════════════════════════════════════
INSERT INTO dim_platform (Platform)
SELECT DISTINCT Platform
FROM stg_historical
WHERE Platform IS NOT NULL AND LTRIM(RTRIM(Platform)) <> ''
UNION
SELECT 'PS4'
UNION
SELECT 'XOne';
GO

SELECT 'dim_platform' AS tabla, COUNT(*) AS filas FROM dim_platform;
GO

-- ══════════════════════════════════════════════════
-- POBLAR dim_genre
-- ══════════════════════════════════════════════════
INSERT INTO dim_genre (Genre)
SELECT DISTINCT Genre
FROM (
    SELECT Genre FROM stg_historical
    UNION ALL
    SELECT Genre FROM stg_ps4
    UNION ALL
    SELECT Genre FROM stg_xbox
) t
WHERE Genre IS NOT NULL AND LTRIM(RTRIM(Genre)) <> '';
GO

SELECT 'dim_genre' AS tabla, COUNT(*) AS filas FROM dim_genre;
GO

-- ══════════════════════════════════════════════════
-- POBLAR dim_publisher
-- ══════════════════════════════════════════════════
INSERT INTO dim_publisher (Publisher)
SELECT DISTINCT Publisher
FROM (
    SELECT Publisher FROM stg_historical
    UNION ALL
    SELECT Publisher FROM stg_ps4
    UNION ALL
    SELECT Publisher FROM stg_xbox
) t
WHERE Publisher IS NOT NULL AND LTRIM(RTRIM(Publisher)) <> '';
GO

SELECT 'dim_publisher' AS tabla, COUNT(*) AS filas FROM dim_publisher;
GO

-- ══════════════════════════════════════════════════
-- POBLAR dim_time
-- ══════════════════════════════════════════════════
DELETE FROM dim_time;
GO

INSERT INTO dim_time (year, decade, era)
SELECT DISTINCT
    CAST(CAST(yr AS FLOAT) AS INT),           -- '1990.0' → 1990.0 → 1990
    (CAST(CAST(yr AS FLOAT) AS INT) / 10) * 10,
    CASE
        WHEN CAST(CAST(yr AS FLOAT) AS INT) <= 1999 THEN 'Classic (<=1999)'
        WHEN CAST(CAST(yr AS FLOAT) AS INT) <= 2009 THEN 'Modern (2000-2009)'
        ELSE 'Current (2010+)'
    END
FROM (
    SELECT Year_of_Release AS yr FROM stg_historical
    UNION
    SELECT Year            AS yr FROM stg_ps4
    UNION
    SELECT Year            AS yr FROM stg_xbox
) t
WHERE yr IS NOT NULL
  AND LTRIM(RTRIM(yr)) <> ''
  AND ISNUMERIC(yr) = 1
ORDER BY 1;
GO

-- Verificar
SELECT 'dim_time' AS tabla, COUNT(*) AS filas FROM dim_time;
GO

-- ══════════════════════════════════════════════════
-- POBLAR dim_game
-- ══════════════════════════════════════════════════
INSERT INTO dim_game (Name, Developer, Rating)
SELECT Name, Developer, Rating
FROM (
    SELECT DISTINCT
        Name,
        NULLIF(LTRIM(RTRIM(Developer)), '') AS Developer,
        NULLIF(LTRIM(RTRIM(Rating)),    '') AS Rating
    FROM stg_historical
    WHERE Name IS NOT NULL AND LTRIM(RTRIM(Name)) <> ''
    UNION
    SELECT DISTINCT
        Game, NULL, NULL
    FROM stg_ps4
    WHERE Game IS NOT NULL AND LTRIM(RTRIM(Game)) <> ''
    UNION
    SELECT DISTINCT
        Game, NULL, NULL
    FROM stg_xbox
    WHERE Game IS NOT NULL AND LTRIM(RTRIM(Game)) <> ''
) t;
GO

SELECT 'dim_game' AS tabla, COUNT(*) AS filas FROM dim_game;
GO

-- ══════════════════════════════════════════════════
-- POBLAR fact_sales — desde PS4
-- ══════════════════════════════════════════════════
INSERT INTO fact_sales (
    game_id, platform_id, genre_id, publisher_id, time_id,
    NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales,
    Critic_Score, source)
SELECT
    g.game_id,
    p.platform_id,
    ge.genre_id,
    pub.publisher_id,
    t.time_id,
    TRY_CAST(s.North_America AS FLOAT),
    TRY_CAST(s.Europe        AS FLOAT),
    TRY_CAST(s.Japan         AS FLOAT),
    TRY_CAST(s.Rest_of_World AS FLOAT),
    TRY_CAST(s.Global        AS FLOAT),
    NULL,
    'PS4_Specific'
FROM stg_ps4 s
LEFT JOIN dim_game      g   ON g.Name        = s.Game
LEFT JOIN dim_platform  p   ON p.Platform    = 'PS4'
LEFT JOIN dim_genre     ge  ON ge.Genre      = s.Genre
LEFT JOIN dim_publisher pub ON pub.Publisher = s.Publisher
LEFT JOIN dim_time      t   ON t.year        = TRY_CAST(s.Year AS INT);
GO

SELECT 'fact_sales PS4' AS origen, COUNT(*) AS filas
FROM fact_sales WHERE source = 'PS4_Specific';
GO

-- ══════════════════════════════════════════════════
-- POBLAR fact_sales — desde Xbox One
-- ══════════════════════════════════════════════════
INSERT INTO fact_sales (
    game_id, platform_id, genre_id, publisher_id, time_id,
    NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales,
    Critic_Score, source)
SELECT
    g.game_id,
    p.platform_id,
    ge.genre_id,
    pub.publisher_id,
    t.time_id,
    TRY_CAST(s.North_America AS FLOAT),
    TRY_CAST(s.Europe        AS FLOAT),
    TRY_CAST(s.Japan         AS FLOAT),
    TRY_CAST(s.Rest_of_World AS FLOAT),
    TRY_CAST(s.Global        AS FLOAT),
    NULL,
    'Xbox_Specific'
FROM stg_xbox s
LEFT JOIN dim_game      g   ON g.Name        = s.Game
LEFT JOIN dim_platform  p   ON p.Platform    = 'XOne'
LEFT JOIN dim_genre     ge  ON ge.Genre      = s.Genre
LEFT JOIN dim_publisher pub ON pub.Publisher = s.Publisher
LEFT JOIN dim_time      t   ON t.year        = TRY_CAST(s.Year AS INT);
GO

SELECT 'fact_sales Xbox' AS origen, COUNT(*) AS filas
FROM fact_sales WHERE source = 'Xbox_Specific';
GO

-- ══════════════════════════════════════════════════
-- POBLAR fact_sales — desde Histórico
-- ══════════════════════════════════════════════════
INSERT INTO fact_sales (
    game_id, platform_id, genre_id, publisher_id, time_id,
    NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales,
    Critic_Score, source)
SELECT
    g.game_id,
    p.platform_id,
    ge.genre_id,
    pub.publisher_id,
    t.time_id,
    TRY_CAST(s.NA_Sales     AS FLOAT),
    TRY_CAST(s.EU_Sales     AS FLOAT),
    TRY_CAST(s.JP_Sales     AS FLOAT),
    TRY_CAST(s.Other_Sales  AS FLOAT),
    TRY_CAST(s.Global_Sales AS FLOAT),
    TRY_CAST(s.Critic_Score AS FLOAT),
    'Historical'
FROM stg_historical s
LEFT JOIN dim_game      g   ON g.Name        = s.Name
LEFT JOIN dim_platform  p   ON p.Platform    = s.Platform
LEFT JOIN dim_genre     ge  ON ge.Genre      = s.Genre
LEFT JOIN dim_publisher pub ON pub.Publisher = s.Publisher
LEFT JOIN dim_time      t   ON t.year        = TRY_CAST(s.Year_of_Release AS INT);
GO

SELECT 'fact_sales Historical' AS origen, COUNT(*) AS filas
FROM fact_sales WHERE source = 'Historical';
GO

-- ══════════════════════════════════════════════════
-- CONSULTAS DE PRUEBA OLAP
-- ══════════════════════════════════════════════════

-- Ventas por género
SELECT
    ge.Genre,
    ROUND(SUM(f.Global_Sales), 2) AS total_M,
    COUNT(*)                       AS registros
FROM fact_sales f
JOIN dim_genre ge ON f.genre_id = ge.genre_id
GROUP BY ge.Genre
ORDER BY total_M DESC;
GO

-- PS4 vs Xbox One
SELECT
    p.Platform,
    COUNT(*)                       AS juegos,
    ROUND(SUM(f.Global_Sales), 2)  AS ventas_M,
    ROUND(AVG(f.Global_Sales), 3)  AS promedio_M
FROM fact_sales f
JOIN dim_platform p ON f.platform_id = p.platform_id
WHERE p.Platform IN ('PS4', 'XOne')
GROUP BY p.Platform;
GO