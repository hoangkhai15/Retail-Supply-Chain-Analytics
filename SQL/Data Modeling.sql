IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'core')
BEGIN
    EXEC('CREATE SCHEMA core')
END
GO

-- ============================================================
-- DIM: Customer
-- ============================================================
CREATE TABLE DimCustomer (
    CustomerKey     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID      NVARCHAR(20)    NOT NULL UNIQUE,
    CustomerName    NVARCHAR(100)   NOT NULL,
    Segment         NVARCHAR(50)    NOT NULL
);

INSERT INTO DimCustomer (CustomerID, CustomerName, Segment)
SELECT DISTINCT
    [Customer ID],
    [Customer Name],
    [Segment]
FROM [RetailSales_Cleaned]
ORDER BY [Customer ID];

SELECT * FROM DimCustomer;
-- ============================================================
-- DIM: Product
-- ============================================================
CREATE TABLE DimProduct (
    ProductKey      INT IDENTITY(1,1) PRIMARY KEY,
    ProductID       NVARCHAR(50)    NOT NULL UNIQUE,
    ProductName     NVARCHAR(255)   NOT NULL,
    Category        NVARCHAR(50)    NOT NULL,
    SubCategory     NVARCHAR(50)    NOT NULL
);

INSERT INTO DimProduct (ProductID, ProductName, Category, SubCategory)
SELECT
    [Product ID],
    MAX([Product Name])     AS ProductName,   -- picks one name when duplicates exist
    MAX([Category])         AS Category,
    MAX([Sub-Category])     AS SubCategory
FROM [RetailSales_Cleaned]
GROUP BY [Product ID]                      
ORDER BY [Product ID];

-- Verify 
SELECT [ProductID], COUNT(*) AS cnt
FROM DimProduct
GROUP BY [ProductID]
HAVING COUNT(*) > 1;

SELECT * FROM DimProduct;
-- ============================================================
-- DIM: Location
-- ============================================================
CREATE TABLE DimLocation (
    LocationKey     INT IDENTITY(1,1) PRIMARY KEY,
    City            NVARCHAR(100)   NOT NULL,
    State           NVARCHAR(100)   NOT NULL,
    Region          NVARCHAR(50)    NOT NULL,
    Country         NVARCHAR(100)   NOT NULL,
    PostalCode      NVARCHAR(20)    NULL
);

-- Use MAX() so only ONE row per City+State is inserted
INSERT INTO DimLocation (City, State, Region, Country, PostalCode)
SELECT
    [City],
    [State],
    MAX([Region])                       AS Region,
    MAX([Country])                      AS Country,
    MAX(CAST([Postal Code] AS NVARCHAR(20))) AS PostalCode
FROM [RetailSales_Cleaned]
GROUP BY [City], [State]   -- one row per City+State guaranteed
ORDER BY [State], [City];

SELECT * FROM DimLocation
-- ============================================================
-- DIM: Ship Mode
-- ============================================================
CREATE TABLE DimShipMode (
    ShipModeKey     INT IDENTITY(1,1) PRIMARY KEY,
    ShipMode        NVARCHAR(50)    NOT NULL UNIQUE
);

INSERT INTO DimShipMode (ShipMode)
SELECT DISTINCT [Ship Mode]
FROM [RetailSales_Cleaned]
ORDER BY [Ship Mode];

SELECT * FROM DimShipMode;
-- ============================================================
-- DIM: Sales Person
-- ============================================================
CREATE TABLE DimSalesPerson (
    SalesPersonKey  INT IDENTITY(1,1) PRIMARY KEY,
    SalesPersonName NVARCHAR(100)   NOT NULL UNIQUE
);

INSERT INTO DimSalesPerson (SalesPersonName)
SELECT DISTINCT [Retail Sales People]
FROM [RetailSales_Cleaned]
ORDER BY [Retail Sales People];

SELECT * FROM DimSalesPerson;
-- ============================================================
-- DIM: Date (covers every date in the dataset)
-- ============================================================
CREATE TABLE DimDate (
    DateKey         INT             PRIMARY KEY,
    FullDate        DATE            NOT NULL,
    DayOfMonth      INT             NOT NULL,
    DayName         NVARCHAR(20)    NOT NULL,
    WeekOfYear      INT             NOT NULL,
    Month           INT             NOT NULL,
    MonthName       NVARCHAR(20)    NOT NULL,
    Quarter         INT             NOT NULL,
    QuarterName     NVARCHAR(10)    NOT NULL,
    Year            INT             NOT NULL,
    IsWeekend       BIT             NOT NULL
);

DECLARE @StartDate DATE = (
    SELECT MIN(MinDate) FROM (
        SELECT MIN(CAST([Order Date] AS DATE)) AS MinDate FROM [RetailSales_Cleaned]
        UNION ALL
        SELECT MIN(CAST([Ship Date]  AS DATE)) FROM [RetailSales_Cleaned]
    ) AS X
);

DECLARE @EndDate DATE = (
    SELECT MAX(MaxDate) FROM (
        SELECT MAX(CAST([Order Date] AS DATE)) AS MaxDate FROM [RetailSales_Cleaned]
        UNION ALL
        SELECT MAX(CAST([Ship Date]  AS DATE)) FROM [RetailSales_Cleaned]
    ) AS X
);

PRINT 'Building DimDate from ' + CAST(@StartDate AS NVARCHAR) + 
      ' to ' + CAST(@EndDate AS NVARCHAR);

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO DimDate
    VALUES (
        CAST(FORMAT(@StartDate, 'yyyyMMdd') AS INT),
        @StartDate,
        DAY(@StartDate),
        DATENAME(WEEKDAY, @StartDate),
        DATEPART(WEEK,    @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH,   @StartDate),
        DATEPART(QUARTER, @StartDate),
        'Q' + CAST(DATEPART(QUARTER, @StartDate) AS NVARCHAR),
        YEAR(@StartDate),
        CASE WHEN DATENAME(WEEKDAY, @StartDate) 
             IN ('Saturday','Sunday') THEN 1 ELSE 0 END
    );
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;

SELECT * FROM DimDate
-- ============================================================
-- FACT: Sales
-- ============================================================
CREATE TABLE FactSales (
    SalesKey        INT IDENTITY(1,1) PRIMARY KEY,
    OrderID         NVARCHAR(20)    NOT NULL,
    RowID           INT             NOT NULL,
    CustomerKey     INT             NOT NULL REFERENCES DimCustomer(CustomerKey),
    ProductKey      INT             NOT NULL REFERENCES DimProduct(ProductKey),
    LocationKey     INT             NOT NULL REFERENCES DimLocation(LocationKey),
    ShipModeKey     INT             NOT NULL REFERENCES DimShipMode(ShipModeKey),
    SalesPersonKey  INT             NOT NULL REFERENCES DimSalesPerson(SalesPersonKey),
    OrderDateKey    INT             NOT NULL REFERENCES DimDate(DateKey),
    ShipDateKey     INT             NOT NULL REFERENCES DimDate(DateKey),
    Sales           DECIMAL(12,4)   NOT NULL,
    Quantity        INT             NOT NULL,
    Discount        DECIMAL(6,4)    NOT NULL,
    Profit          DECIMAL(12,4)   NOT NULL,
    ProfitMarginPct DECIMAL(8,2)    NULL,
    LeadTimeDays    INT             NULL,
    IsReturned      BIT             NOT NULL DEFAULT 0
);
-- ============================================================
-- INSERT into FactSales — join all dimension keys
-- ============================================================
INSERT INTO FactSales (
    OrderID, RowID,
    CustomerKey, ProductKey, LocationKey,
    ShipModeKey, SalesPersonKey,
    OrderDateKey, ShipDateKey,
    Sales, Quantity, Discount, Profit,
    ProfitMarginPct, LeadTimeDays, IsReturned
)
SELECT
    r.[Order ID],
    r.[Row ID],
    c.CustomerKey,
    p.ProductKey,
    l.LocationKey,
    sm.ShipModeKey,
    sp.SalesPersonKey,
    CAST(FORMAT(CAST(r.[Order Date] AS DATE), 'yyyyMMdd') AS INT),
    CAST(FORMAT(CAST(r.[Ship Date]  AS DATE), 'yyyyMMdd') AS INT),
    r.[Sales],
    r.[Quantity],
    r.[Discount],
    r.[Profit],
    r.[Profit Margin (%)],
    r.[Lead Time (days)],
    r.[Is Returned]
FROM [RetailSales_Cleaned]      r
JOIN DimCustomer    c   ON r.[Customer ID]          = c.CustomerID
JOIN DimProduct     p   ON r.[Product ID]           = p.ProductID
JOIN DimLocation    l   ON r.[City]  = l.City 
                       AND r.[State] = l.State
JOIN DimShipMode    sm  ON r.[Ship Mode]             = sm.ShipMode
JOIN DimSalesPerson sp  ON r.[Retail Sales People]  = sp.SalesPersonName;
-- Verify row counts match

SELECT 'RetailSales_Cleaned' AS Source, COUNT(*) AS Rows FROM [RetailSales_Cleaned]
UNION ALL
SELECT 'FactSales',                      COUNT(*) AS Rows FROM FactSales;
