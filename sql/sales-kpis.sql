----Super Store Data----
--1.RFM Segmentation
WITH rfm AS (
  SELECT 
    "Customer ID",
    "Customer Name",
    COUNT(DISTINCT "Order ID") as Frequency,
    SUM("Sales") as Monetary,
    MAX("Order Date") as Last_Order,
    CURRENT_DATE - MAX("Order Date") as Recency_days
  FROM Superstore
  GROUP BY 1,2
),
rfm_scores AS (
  SELECT *,
    NTILE(5) OVER (ORDER BY Recency_days) as R_Score,
    NTILE(5) OVER (ORDER BY Frequency DESC) as F_Score,
    NTILE(5) OVER (ORDER BY Monetary DESC) as M_Score
  FROM rfm
)
SELECT 
  CONCAT(R_Score, F_Score, M_Score) as RFM_Segment,
  COUNT(*) as Customer_Count,
  ROUND(AVG(Frequency),1) as Avg_Orders,
  ROUND(AVG(Monetary),0) as Avg_Spend,
  ROUND(SUM(Monetary),0) as Total_Revenue
FROM rfm_scores
GROUP BY 1
ORDER BY Total_Revenue DESC;

-- 2. PROFITABILITY HEATMAP (Category + Subcategory)
WITH profit_matrix AS (
  SELECT 
    "Category",
    "Sub-Category",
    SUM("Sales") as Cat_Sales,
    SUM("Profit") as Cat_Profit,
    COUNT(*) as Order_Count,
    ROUND((SUM("Profit")/NULLIF(SUM("Sales"),0))*100,2) as Profit_Margin_pct,
    AVG("Quantity") as Avg_Qty
  FROM Superstore
  GROUP BY 1,2
)
SELECT * FROM profit_matrix
ORDER BY Cat_Profit DESC;

-- 3. BASKET ANALYSIS (Cross-sell Opportunities)
WITH baskets AS (
  SELECT 
    "Order ID",
    "Sub-Category",
    SUM("Sales") as Item_Sales
  FROM Superstore 
  GROUP BY 1,2
),
combinations AS (
  SELECT 
    b1."Sub-Category" as Item1,
    b2."Sub-Category" as Item2,
    COUNT(*) as Co_Occurrence,
    ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (PARTITION BY b1."Sub-Category"), 2) as Affinity_Score
  FROM baskets b1
  JOIN baskets b2 ON b1."Order ID" = b2."Order ID" AND b1."Sub-Category" < b2."Sub-Category"
  GROUP BY 1,2
  HAVING COUNT(*) >= 10
)
SELECT * FROM combinations
ORDER BY Co_Occurrence DESC
LIMIT 10;

-- 4. WEEKLY TREND + FORECAST PREP (Time Series)
WITH weekly_trends AS (
  SELECT 
    DATE_TRUNC('week', "Order Date") as Week_Ending,
    SUM("Sales") as Weekly_Sales,
    SUM("Profit") as Weekly_Profit,
    COUNT(DISTINCT "Customer ID") as Weekly_Customers,
    LAG(SUM("Sales"), 1) OVER (ORDER BY DATE_TRUNC('week', "Order Date")) as Prev_Week_Sales,
    LAG(SUM("Profit"), 1) OVER (ORDER BY DATE_TRUNC('week', "Order Date")) as Prev_Week_Profit
  FROM Superstore
  GROUP BY 1
)
SELECT *,
  ROUND(((Weekly_Sales - Prev_Week_Sales)/NULLIF(Prev_Week_Sales,0))*100,2) as WoW_Growth_pct,
  Weekly_Sales - Prev_Week_Sales as Sales_Change
FROM weekly_trends
ORDER BY Week_Ending DESC;

-- 5. SEGMENTED PROFITABILITY (Your TD Bank RLS Demo)
SELECT 
  "Segment",
  "Region",
  SUM("Sales") as Seg_Sales,
  SUM("Profit") as Seg_Profit,
  ROUND(SUM("Profit")*1.0/SUM("Sales"),4)*100 as Profit_Margin
FROM Superstore
GROUP BY 1,2
ORDER BY Seg_Profit DESC;
