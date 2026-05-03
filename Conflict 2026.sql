CREATE DATABASE `Market Analysis`;
USE `Market Analysis`;

-- Create Table
Create Table Market_Prices (
Price_Date Date,
Ticker varchar(20),
Price Decimal(10,4),
Primary Key (Price_Date,Ticker)
);

-- Load the CSV
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.4/Uploads/clean_file.csv'
INTO TABLE Market_Prices
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Create a View which stores daily change in the price and the return of each index everyday.

Create View Returns AS 
Select Price_Date, Ticker, Price, 
(Price - Prev_Price) As Price_Change,
Round((Price - Prev_Price)/NULLIF(Prev_Price,0),4) * 100 AS Return_Percentage
From 
(
	Select *, 
	Lag(Price) Over (Partition By Ticker Order By Price_Date) As Prev_Price
	From Market_Prices
    )t; 
 

-- Create View to store the peak. 
Create View Peak As 
Select Price_Date, Ticker, Price,
Max(Price) Over(partition by Ticker Order by Price_Date Rows between unbounded preceding and current row) as Peak
From Market_Prices;

-- Create View to store the drawdown values

Create View Drawdown As
Select Price_Date, Ticker, Price, Peak,
Round(((Price - Peak)/Peak),4) As Drawdown
From Peak;

-- Gives rank 
Select Price_Date, Ticker, Price,
Dense_Rank() Over(Partition By Ticker Order By Price Desc) as "Dense_Rank"
From Market_Prices;

-- Rolling Average of past 7 days
Select Price_Date, Ticker, Price,
Avg(Price) Over(partition by Ticker Order by Price_Date Rows between 6 preceding and current row) as Rolling_Avg_Price
From Market_Prices; 

-- Descrobes the market situation
SELECT Price_Date, Ticker, Drawdown,
Case
	When Drawdown <= -0.2 THEN "Significant Drawdown"
    WHEN Drawdown <= -0.1 THEN "Moderate Drawdown"
    ELSE "Minor Drawdown"
END AS Market_Condition
From Drawdown;

-- Create View which calculates volatility for 7 days and 30 days
Create View Volatile As 
Select Price_Date, Ticker,
  -- 7-Day for immediate panic
  Round(stddev(Price) over(partition by Ticker order by Price_Date 
    rows between 6 preceding and current row),4) as Short_Term_Vol,
  -- 30-Day for sustained trend
  Round(stddev(Price) over(partition by Ticker order by Price_Date 
    rows between 29 preceding and current row),4) as Monthly_Vol
From Market_Prices;
 
 
-- Create a Master View for Returns, Peak, Drawdown, Volatitlity
CREATE VIEW Market_Master AS
SELECT 
    r.Price_Date, 
    r.Ticker, 
    r.Price, 
    r.Return_Percentage,
    p.Peak,
    d.Drawdown,
    v.Short_Term_Vol,
    
         
	Case
		When d.Drawdown <= -0.2 THEN "Significant Drawdown"
		WHEN d.Drawdown <= -0.1 THEN "Moderate Drawdown"
		ELSE "Stable"
	END AS Market_Condition
    
FROM Returns r
Join Peak p ON r.Price_Date = p.Price_Date AND r.Ticker = p.Ticker
JOIN Drawdown d ON r.Price_Date = d.Price_Date AND r.Ticker = d.Ticker
JOIN volatile v ON r.Price_Date = v.Price_Date AND r.Ticker = v.Ticker;

Select * 
From Market_Master;


-- To calculate how long the crude oil was at its peak.
Select Ticker, Count(*) as Times_at_Peak
From Peak
Where Price = Peak
AND Ticker = "Crude_Oil"
Group By Ticker;

-- To check whether Crude Oil or S&P 500 was better asset during this time of uncertainity
Select a.Price_date,
a.Price As Oil_Price,
b.Price AS SP500_Price,
a.Return_Percentage AS Oil_Return, 
b.Return_Percentage AS SP500_Return,
(a.Return_Percentage - b.Return_Percentage ) AS Sector_Difference
From Returns a
Join Returns b on a.Price_Date = b.Price_Date
Where a.Ticker = "Crude_Oil" and b.Ticker = "SP500";

-- To check the sector difference during the war events
Select *
From (Select a.Price_date,
a.Price As Oil_Pricee,
b.Price AS SP500_Price,
a.Return_Percentage AS Oil_Return, 
b.Return_Percentage AS SP500_Return,
(a.Return_Percentage - b.Return_Percentage ) AS Sector_Difference
From Returns a
Join Returns b on a.Price_Date = b.Price_Date
Where a.Ticker = "Crude_Oil" and b.Ticker = "SP500") b
Where Price_Date Between "2026-02-28" AND "2026-04-07";

-- Worst Drawdown
SELECT 
    Ticker,
    MIN(Drawdown) AS Max_Drawdown
FROM Drawdown
GROUP BY Ticker;

Drop view vw_market_master