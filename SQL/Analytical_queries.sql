-- ============================================================
-- Revenue and Profit by Product Category
-- ============================================================
SELECT
    p.Category,
    COUNT(DISTINCT f.SalesKey)              AS total_orders,
    SUM(f.Quantity)                          AS total_units_sold,
    ROUND(SUM(f.Sales), 2)                   AS total_revenue,
    ROUND(SUM(f.Profit), 2)                  AS total_profit,
    ROUND(AVG(f.Discount) * 100, 2)          AS avg_discount_pct,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS profit_margin_pct

FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey

GROUP BY p.Category
ORDER BY total_revenue DESC;

-- ============================================================
-- Monthly Revenue Trend
-- ============================================================
SELECT
    dd.Year                             AS order_year,
    dd.Month                            AS order_month,
    dd.MonthName                        AS month_name,
    ROUND(SUM(f.Sales), 2)              AS total_revenue,
    ROUND(SUM(f.Profit), 2)             AS total_profit,
    COUNT(DISTINCT f.OrderID)           AS total_orders

FROM FactSales f
JOIN DimDate dd ON f.OrderDateKey = dd.DateKey

GROUP BY dd.Year, dd.Month, dd.MonthName
ORDER BY dd.Year, dd.Month;
-- ============================================================
-- Top 10 Customers by Revenue
-- ============================================================
SELECT TOP 10
    c.CustomerID,
    c.CustomerName,
    c.Segment,
    COUNT(DISTINCT f.OrderID)           AS total_orders,
    SUM(f.Quantity)                     AS total_units,
    ROUND(SUM(f.Sales), 2)              AS total_revenue,
    ROUND(SUM(f.Profit), 2)             AS total_profit

FROM FactSales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey

GROUP BY c.CustomerID, c.CustomerName, c.Segment
ORDER BY total_revenue DESC;
-- ============================================================
-- Profit Margin by Sub-Category (loss-makers at top)
-- ============================================================
SELECT
    p.Category,
    p.SubCategory,
    COUNT(DISTINCT f.OrderID)           AS total_orders,
    ROUND(SUM(f.Sales), 2)              AS total_revenue,
    ROUND(SUM(f.Profit), 2)             AS total_profit,
    ROUND(AVG(f.Discount) * 100, 2)     AS avg_discount_pct,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS profit_margin_pct

FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey

GROUP BY p.Category, p.SubCategory
ORDER BY total_profit ASC;   -- loss-makers at top
-- ============================================================
-- Return Rate by Category
-- ============================================================
SELECT
    p.Category,
    COUNT(f.SalesKey)                                           AS total_orders,
    SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END)          AS returned_orders,
    ROUND(
        100.0 * SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(f.SalesKey), 0), 2
    )                                                           AS return_rate_pct,
    ROUND(SUM(CASE WHEN f.IsReturned = 1 THEN f.Sales  ELSE 0 END), 2) AS lost_revenue,
    ROUND(SUM(CASE WHEN f.IsReturned = 1 THEN f.Profit ELSE 0 END), 2) AS lost_profit

FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey

GROUP BY p.Category
ORDER BY return_rate_pct DESC;
-- ============================================================
-- Shipping Performance by Region
-- ============================================================
SELECT
    l.Region,
    sm.ShipMode,
    COUNT(DISTINCT f.OrderID)               AS total_orders,
    ROUND(AVG(CAST(f.LeadTimeDays AS FLOAT)), 1) AS avg_days_to_ship,
    MIN(f.LeadTimeDays)                     AS min_days,
    MAX(f.LeadTimeDays)                     AS max_days

FROM FactSales f
JOIN DimLocation    l  ON f.LocationKey  = l.LocationKey
JOIN DimShipMode    sm ON f.ShipModeKey  = sm.ShipModeKey

GROUP BY l.Region, sm.ShipMode
ORDER BY l.Region, avg_days_to_ship;
-- ============================================================
-- Year-over-Year Revenue Growth by Category
-- ============================================================
WITH yearly_revenue AS (
    SELECT
        p.Category,
        dd.Year                         AS order_year,
        ROUND(SUM(f.Sales), 2)          AS total_revenue,
        ROUND(SUM(f.Profit), 2)         AS total_profit
    FROM FactSales f
    JOIN DimProduct p  ON f.ProductKey   = p.ProductKey
    JOIN DimDate    dd ON f.OrderDateKey = dd.DateKey
    GROUP BY p.Category, dd.Year
)
SELECT
    Category,
    order_year,
    total_revenue,
    total_profit,
    LAG(total_revenue) OVER (
        PARTITION BY Category ORDER BY order_year
    )                                   AS prev_year_revenue,
    ROUND(
        100.0 * (total_revenue - LAG(total_revenue) OVER (
            PARTITION BY Category ORDER BY order_year
        ))
        / NULLIF(LAG(total_revenue) OVER (
            PARTITION BY Category ORDER BY order_year
        ), 0), 2
    )                                   AS yoy_growth_pct

FROM yearly_revenue
ORDER BY Category, order_year;
-- ============================================================
-- Salesperson Ranking by Revenue
-- ============================================================
SELECT
    sp.SalesPersonName,
    COUNT(DISTINCT f.OrderID)           AS total_orders,
    COUNT(DISTINCT f.CustomerKey)       AS unique_customers,
    ROUND(SUM(f.Sales), 2)              AS total_revenue,
    ROUND(SUM(f.Profit), 2)             AS total_profit,
    ROUND(AVG(f.Sales), 2)              AS avg_order_value,
    ROUND(AVG(f.Discount) * 100, 2)     AS avg_discount_pct,
    RANK() OVER (ORDER BY SUM(f.Sales)  DESC) AS revenue_rank,
    RANK() OVER (ORDER BY SUM(f.Profit) DESC) AS profit_rank

FROM FactSales f
JOIN DimSalesPerson sp ON f.SalesPersonKey = sp.SalesPersonKey

GROUP BY sp.SalesPersonName
ORDER BY revenue_rank;
-- ============================================================
-- Running Total of Revenue by Month
-- ============================================================
WITH monthly AS (
    SELECT
        dd.Year                         AS order_year,
        dd.Month                        AS order_month,
        dd.MonthName                    AS month_name,
        ROUND(SUM(f.Sales), 2)          AS monthly_revenue,
        ROUND(SUM(f.Profit), 2)         AS monthly_profit
    FROM FactSales f
    JOIN DimDate dd ON f.OrderDateKey = dd.DateKey
    GROUP BY dd.Year, dd.Month, dd.MonthName
)
SELECT
    order_year,
    order_month,
    month_name,
    monthly_revenue,
    monthly_profit,
    ROUND(SUM(monthly_revenue) OVER (
        ORDER BY order_year, order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                               AS running_total_revenue

FROM monthly
ORDER BY order_year, order_month;
-- ============================================================
-- Top 3 Products per Category by Revenue
-- ============================================================
WITH ranked AS (
    SELECT
        p.Category,
        p.SubCategory,
        p.ProductName,
        ROUND(SUM(f.Sales), 2)          AS total_revenue,
        ROUND(SUM(f.Profit), 2)         AS total_profit,
        COUNT(DISTINCT f.OrderID)       AS total_orders,
        ROW_NUMBER() OVER (
            PARTITION BY p.Category
            ORDER BY SUM(f.Sales) DESC
        )                               AS rank_in_category
    FROM FactSales f
    JOIN DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY p.Category, p.SubCategory, p.ProductName
)
SELECT
    Category,
    rank_in_category        AS rank,
    SubCategory,
    ProductName,
    total_revenue,
    total_profit,
    total_orders

FROM ranked
WHERE rank_in_category <= 3
ORDER BY Category, rank_in_category;
-- ============================================================
-- Customer Cohort  LTV Tiers
-- Group customers into High / Mid / Low value and compare behaviour
-- ============================================================
WITH CustomerLTV AS (
    SELECT
        c.CustomerKey,
        c.CustomerName,
        c.Segment,
        l.Region,
        MIN(dd.Year)                            AS first_order_year,
        MAX(dd.Year)                            AS last_order_year,
        COUNT(DISTINCT f.OrderID)               AS total_orders,
        ROUND(SUM(f.Sales), 2)                  AS lifetime_revenue,
        ROUND(SUM(f.Profit), 2)                 AS lifetime_profit,
        ROUND(AVG(f.Sales), 2)                  AS avg_order_value,
        SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END) AS total_returns
    FROM FactSales f
    JOIN DimCustomer c  ON f.CustomerKey  = c.CustomerKey
    JOIN DimLocation l  ON f.LocationKey  = l.LocationKey
    JOIN DimDate     dd ON f.OrderDateKey = dd.DateKey
    GROUP BY c.CustomerKey, c.CustomerName, c.Segment, l.Region
),
WithTier AS (
    SELECT *,
        CASE
            WHEN lifetime_revenue >= 5000 THEN 'A - High LTV'
            WHEN lifetime_revenue >= 1000 THEN 'B - Mid LTV'
            ELSE                               'C - Low LTV'
        END AS ltv_tier
    FROM CustomerLTV
)
SELECT
    ltv_tier,
    COUNT(*)                                AS num_customers,
    ROUND(AVG(lifetime_revenue), 2)         AS avg_lifetime_revenue,
    ROUND(AVG(lifetime_profit), 2)          AS avg_lifetime_profit,
    ROUND(AVG(avg_order_value), 2)          AS avg_order_value,
    ROUND(AVG(CAST(total_orders  AS FLOAT)), 1) AS avg_orders,
    ROUND(AVG(CAST(total_returns AS FLOAT)), 1) AS avg_returns
FROM WithTier
GROUP BY ltv_tier
ORDER BY ltv_tier;
-- ============================================================
-- Salesperson KPI Scorecard
-- Full performance breakdown  revenue, profit, discounts, returns
-- ============================================================
WITH SalesPersonStats AS (
    SELECT
        sp.SalesPersonName,
        dd.Year                                                     AS order_year,
        dd.Quarter                                                  AS order_quarter,
        COUNT(DISTINCT f.OrderID)                                   AS total_orders,
        COUNT(DISTINCT f.CustomerKey)                               AS unique_customers,
        ROUND(SUM(f.Sales), 2)                                      AS total_revenue,
        ROUND(SUM(f.Profit), 2)                                     AS total_profit,
        ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 1)    AS profit_margin_pct,
        ROUND(AVG(f.Discount) * 100, 1)                             AS avg_discount_pct,
        SUM(CASE WHEN f.Discount > 0.20 THEN 1 ELSE 0 END)         AS heavy_discount_orders,
        SUM(CASE WHEN f.IsReturned = 1  THEN 1 ELSE 0 END)         AS returned_orders,
        ROUND(100.0 * SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(f.SalesKey), 0), 1)                    AS return_rate_pct
    FROM FactSales f
    JOIN DimSalesPerson sp ON f.SalesPersonKey = sp.SalesPersonKey
    JOIN DimDate        dd ON f.OrderDateKey   = dd.DateKey
    GROUP BY sp.SalesPersonName, dd.Year, dd.Quarter
)
SELECT
    SalesPersonName,
    order_year,
    order_quarter,
    total_orders,
    unique_customers,
    total_revenue,
    total_profit,
    profit_margin_pct,
    avg_discount_pct,
    heavy_discount_orders,
    returned_orders,
    return_rate_pct,
    RANK() OVER (PARTITION BY order_year, order_quarter 
                 ORDER BY total_revenue DESC)   AS revenue_rank_in_quarter

FROM SalesPersonStats
ORDER BY SalesPersonName, order_year, order_quarter;
-- ============================================================
-- Returns Deep-Dive
-- Top 10 most returned products + financial damage
-- ============================================================
SELECT TOP 10
    p.ProductName,
    p.Category,
    p.SubCategory,
    COUNT(f.SalesKey)                                               AS total_orders,
    SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END)              AS times_returned,
    ROUND(100.0 * SUM(CASE WHEN f.IsReturned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(f.SalesKey), 0), 1)                        AS return_rate_pct,
    ROUND(SUM(CASE WHEN f.IsReturned = 1 THEN f.Sales  ELSE 0 END), 2) AS lost_revenue,
    ROUND(SUM(CASE WHEN f.IsReturned = 1 THEN f.Profit ELSE 0 END), 2) AS lost_profit,
    ROUND(AVG(f.Discount) * 100, 1)                                 AS avg_discount_pct

FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey

GROUP BY p.ProductName, p.Category, p.SubCategory
HAVING COUNT(f.SalesKey) >= 3
ORDER BY times_returned DESC;
