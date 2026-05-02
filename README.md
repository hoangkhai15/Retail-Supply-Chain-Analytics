# Retail-Supply-Chain-Analytics
End-to-end retail sales analytics project — Python EDA, SQL Server Star Schema data modelling, and Power BI dashboard built on 9,994 orders across 4 regions and 3 product categories.


## Tools Used
- **Python** — exploratory data analysis, data cleaning, feature engineering
- **SQL Server** — star schema data modelling and analytical queries
- **Power BI** — interactive business dashboard

---

## Dataset
9,994 order line items covering sales, profit, discount, shipping and returns across the US retail market in 2017.

---

## Project Steps

**1. Exploratory Data Analysis (Python)**
Loaded and inspected the raw data, checked for missing values, analysed distributions, identified trends across time, region, category and customer segments.

**2. Data Cleaning & Feature Engineering**
Fixed date types, derived new columns including Order Year, Order Month, Order Quarter, Lead Time in days, Profit Margin % and Is Returned flag.

**3. Star Schema — SQL Server**
Designed and built a star schema with 6 dimension tables (DimCustomer, DimProduct, DimDate, DimLocation, DimShipMode, DimSalesPerson) and one central FactSales table.

**4. Analytical SQL Queries**
Wrote 13 business queries covering revenue by category, monthly trends, top customers, return rate analysis, salesperson KPIs, cohort analysis and year-over-year growth.

**5. Power BI Dashboard**
Built an interactive dashboard connected live to SQL Server covering sales overview, regional performance, profitability and operational efficiency.

---

## Key Findings
- Technology drives the highest revenue but Office Supplies has the strongest profit margin
- Orders discounted above 20% consistently generate negative average profit
- Tables and Bookcases are loss-making sub-categories
- Q4 is peak season with the largest revenue spike of the year
- Overall return rate is approximately 30% of all orders

---

## How to Run

**Python**
```bash
pip install pandas numpy matplotlib seaborn pyodbc sqlalchemy jupyter
jupyter notebook python/retail_eda_analysis.ipynb
```
Run sections 1 to 3 first to clean the data, then run Section 10 to upload to SQL Server.

**SQL Server**
Run the files in order in SSMS:
```
01_Data Modelling.sql
02_analytical_queries.sql
```

**Power BI**
Open the .pbix file, update the server name in Data Source Settings to your local SQL Server instance, then click Refresh.

---

## Folder Structure
```
retail-supply-chain-analytics/
├── data/
│   └── RetailSupplyChainSalesDataset.csv
├── python/
│   └── retail_eda_analysis.ipynb
├── sql/
│   ├── 01_Data Modelling.sql
│   ├── 02_Analytical_queries.sql
└── powerbi/
    └── RetailSuppyChain_Dashboard.pbix
```

---

