

select * from layoffs_raw$;

-- 1. Create staging table with the same columns and data types
SELECT *
INTO layoffs_staging
FROM layoffs_raw$
WHERE 1 = 0;
--Import the data from raw to staging table
INSERT INTO layoffs_staging
SELECT *
FROM layoffs_raw$;
--Testing
select * from layoffs_staging;

--Phase 1: First Look (Basic EDA)
--How many rows and columns does the table have? [COUNT(*)]
select count(*) from layoffs_staging;

--Look at the first 20 rows. What do you notice that looks wrong or inconsistent? Write your observations down. [SELECT, LIMIT]
select top 20 * from layoffs_staging;

--NULL values are in the industry, total_laid_off,date,funds_raised_millions
--timestamp as 0 for all

--How many NULL or blank values are in each column? [COUNT, CASE WHEN, IS NULL]

select count(*) from layoffs_staging
where  percentage_laid_off ='NULL' ;

select sum(case when industry IS NULL  OR industry ='NULL' then 1 else 0 end) as industry_null,
       sum(case when total_laid_off IS NULL   then 1 else 0 end) as total_paid_off_null,
       sum(case when percentage_laid_off IS NULL OR percentage_laid_off='NULL'  then 1 else 0 end) as percentage_laid_off_null,
       sum(case when date IS NULL then 1 else 0 end) as date_null,
       sum(case when stage Is NULL OR stage ='NULL' then 1 else 0 end) as stage_null,
       sum(case when country is null or country ='NULL' then 1 else 0 end) as country_null,
       sum(case when funds_raised_millions IS NULL  then 1 else 0 end) as funds_raised_milions_null
from layoffs_staging

--What is the date range of the data (earliest and latest)? [MIN, MAX]
select min(date) as start_date, max(date) as end_date from layoffs_staging;

--How many distinct companies, industries, and countries are there? [COUNT(DISTINCT ...)]

select count(distinct company) as cn_company,
       count(distinct industry) as cn_industry,
       count(distinct country) as cn_country
from layoffs_staging;


--Phase 2: Data Cleaning

--Removing duplicates
--8. Which companies appear more than once? Are all of them true duplicates? [GROUP BY, HAVING]

select company, count(*) as duplicate_count
from layoffs_staging
Group by company
Having count(*) > 1
order by duplicate_count DESC;

select * from layoffs_staging where company='Better.com';

--Finding actial duplicate records 
--9. Number the rows within each group of identical records. Which rows have a number greater than 1? [ROW_NUMBER() OVER (PARTITION BY ...)]
with cte as (select *,
       ROW_NUMBER() OVER(partition by company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions order by company ) as row_num
from layoffs_staging)

select * from cte where row_num > 1;




--10. Put that query in a CTE and delete the duplicates. Why can't you always delete straight from a CTE in MySQL, and what's the workaround? [CTEs, a second staging table with a row_num column]

with cte as (select *,
       ROW_NUMBER() OVER(partition by company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions order by company ) as row_num
from layoffs_staging)

delete from cte where row_num>1;

--Handling NULLs and blanks
--11. Which rows have a blank ('') industry? Convert blanks to NULL first. [UPDATE ... SET ... = NULL]

select * from layoffs_staging where ltrim(rtrim(industry))=' ';

--12. Can you fill in a missing industry from another row of the same company? (Example: Airbnb has a row with industry filled and one without.) [self-join, UPDATE ... JOIN]

select 
       l1.company,
       l1.industry as missing_industry,
       l2.industry as available_industry
from layoffs_staging l1
JOIN layoffs_staging l2
ON l1.company=l2.company
where l1.industry IS NULL
AND l2.industry IS NOT NULL;

update l1
set l1.industry = l2.industry
from layoffs_staging l1
JOIN layoffs_staging l2
ON l1.company = l2.company
where l1.industry IS NULL
AND l2.industry IS NOT NULL;

select company,
       count(distinct industry) as industry_count
from layoffs_staging
where industry is not null
group by company
having  count(distinct industry)  > 1;


select * from layoffs_staging where industry IS NULL;

UPDATE layoffs_staging
SET industry = NULL
WHERE industry = 'NULL';

select * from layoffs_staging where company='Bally''s Interactive';

--Bally's Interactive has a missing industry and no other record for the same company, so the value was retained as NULL rather than being assumed.



--13. Which rows have both total_laid_off and percentage_laid_off as NULL? Should you keep them? Write down your decision and the reason. [WHERE ... AND ..., judgment call]

select * from layoffs_staging
where total_laid_off IS NULL and percentage_laid_off IS NULL;


UPDATE layoffs_staging
SET percentage_laid_off = NULL
WHERE percentage_laid_off = 'NULL';

--We can see that percentage_laid_off have varchar null so i am updating as null
select * from layoffs_staging
where total_laid_off IS NULL OR percentage_laid_off IS NULL;

--Should we keep them?
--For this datset, i would remove them 
DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


--Phase 3: Standardization

--Look at DISTINCT industry in alphabetical order. Do you see variants like Crypto, Crypto Currency, CryptoCurrency? Fix them. [DISTINCT, ORDER BY, LIKE, UPDATE]

select distinct industry from layoffs_staging
order by industry ASC;

--Crypto
--Crypto Currency
--CryptoCurrency

update layoffs_staging
set industry='Crypto'
where industry IN ('Crypto Currency', 'CryptoCurrency');

--Do the same for country. Find the issue (for example United States. with a trailing period). [TRIM(TRAILING '.' FROM ...)]

select distinct country from layoffs_staging
order by country ASC;

select distinct country
from layoffs_staging
where country LIKE '%.';

UPDATE layoffs_staging
SET country = LEFT(country, LEN(country) - 1)
WHERE country LIKE '%.';


--Do company names have extra spaces? Fix them. [TRIM()]

select distinct company
from layoffs_staging
order by company ASC;


SELECT *
FROM layoffs_staging
WHERE company <> TRIM(company);

UPDATE layoffs_staging
SET company = TRIM(company);




--The date column is probably stored as text. Convert it to a proper DATE type. This is a two-step process: convert the values, then change the column type. [STR_TO_DATE, ALTER TABLE ... MODIFY COLUMN]

select column_name,
       data_type
from INFORMATION_SCHEMA.COLUMNS
where table_name ='layoffs_staging'
AND column_name='date';

--Check the data types of all numeric columns. Should any be changed? [DESCRIBE, ALTER TABLE]
select column_name,
       data_type
from INFORMATION_SCHEMA.COLUMNS
where table_name ='layoffs_staging';

select * from layoffs_staging where percentage_laid_off ='NULL';

SELECT percentage_laid_off
FROM layoffs_staging
WHERE percentage_laid_off IS NOT NULL
  AND TRY_CONVERT(FLOAT, percentage_laid_off) IS NULL;

  ALTER TABLE layoffs_staging
ALTER COLUMN percentage_laid_off FLOAT;


--Phase 4: Normalization

--In analytics this means rescaling values. If you want the database-design meaning (1NF to 3NF), see Phase 7.

--Calculate the min-max normalized value of total_laid_off (between 0 and 1) for each row. [window functions: (x - MIN(x) OVER()) / (MAX(x) OVER() - MIN(x) OVER())]
--Normalization = converting values to a common scale, often 0 to 1, so different values can be compared more easily.
--formula = x - min(x) / max(x) - min(x) 
select company, 
       total_laid_off,
       cast((total_laid_off - min(total_laid_off) over() ) * 1.0
             / NULLIF(max(total_laid_off) over() - min(total_laid_off) over(), 0) as decimal(10,4)) as normalization_laid_off
from layoffs_staging


--Calculate the z-score of total_laid_off. Which rows have a z-score above 3? What does that tell you about outliers? [AVG() OVER(), STDDEV() OVER()]

with zscore_data as (select company, 
       total_laid_off,
       cast(
              (total_laid_off - avg(total_laid_off) over() ) 
              /
              NULLIF(stdev(total_laid_off) over() , 0)
              AS decimal(10,2)
              ) as z_score
from layoffs_staging 
where total_laid_off is not null)

select * from zscore_data where z_score > 3;

--Create a size bucket for each company based on total_laid_off (Small / Medium / Large / Mega). [CASE WHEN, or NTILE(4)]

select company, total_laid_off,
       case when total_laid_off is null then 'UNknown'
            when total_laid_off < 100 then 'Small'
            when total_laid_off < 500 then 'Medium'
            when total_laid_off < 1000 then 'Large'
        else 'Mega'
    END as company_size
from layoffs_staging;

--Using NTILE 

select company ,
       total_laid_off,
       NTILE(4) over(order by total_laid_off) as size_quartile
from layoffs_staging
where total_laid_off IS NOT NULL;

--Convert percentage_laid_off into a clean 0-100 number and label 100% rows as "Company shut down." [CASE WHEN]
select company,
 percentage_laid_off,
 percentage_laid_off * 100 as per_laid_off_clean
from layoffs_staging;

select company,
       percentage_laid_off,
       case when percentage_laid_off = 1 then 'Company shut down'
            when percentage_laid_off IS NULL then 'Unknown'
            ELSE cast(percentage_laid_off * 100 as varchar(10)) + '%'
        end as layoff_per
from layoffs_staging;


--Phase 5: Exploratory Analysis

--Easy
--23. Which companies had a 100% layoff (went under)? Which had the most funding? [WHERE, ORDER BY]

select avg(funds_raised_millions) from layoffs_staging;

select * from layoffs_staging
where percentage_laid_off = 1 
order by funds_raised_millions DESc;

--24. Which 10 companies laid off the most people in total? [GROUP BY, SUM, ORDER BY, LIMIT]

select top 10 company, sum(total_laid_off) as total
from layoffs_staging
group by company
Order by total DESC;


--25. Which industries and which countries were hit hardest? [GROUP BY]

select Industry, country, sum(total_laid_off) as total
from layoffs_staging
group by industry, country
order by total DESC;



--Medium
--26. How many layoffs happened each year? Which year was the worst? [YEAR(), GROUP BY]

select year(date), sum(total_laid_off) as total
from layoffs_staging
where date is not null
group by year(date) 
order by year(date) ,total DESC;

--27. Show monthly layoffs, then add a rolling (running) total over time. [SUBSTRING/DATE_FORMAT, CTE, SUM() OVER (ORDER BY ...)]

with monthlyLayoffs as (select year(date) as year,
       month(date) as month,
       sum(total_laid_off) as monthly_laid_off
from layoffs_staging
where date is not null
group by year(date), month(date)
)

select *, sum(monthly_laid_off) over(order by year, month) as running_total
from monthlyLayoffs
group by year, month;


--28. Does the company's funding stage (Seed, Series B, Post-IPO...) relate to layoffs? [GROUP BY stage]
select stage,count(distinct company) as companies,
sum(total_laid_off) as total,
avg(total_laid_off) as avg_laid_off
from layoffs_staging
group by stage
order by total DESC;


--29. Which companies lay off people repeatedly? (This is the question the file you found answers. Can you recreate that result yourself?) [COUNT(*), SUM, GROUP BY, HAVING]

select company, count(*) as layoof_events, sum(total_laid_off) as total
from layoffs_staging
where total_laid_off is not null
group by company 
having count(*) > 1;


--Advanced
--30. Rank the top 5 companies by layoffs per year. [CTE + DENSE_RANK() OVER (PARTITION BY year ORDER BY ...)]

with companyYearlyLayOff as (select year(date) as year, company, sum(total_laid_off) as total_laid_off
from layoffs_staging
where date is not null and total_laid_off IS NOT NULL
group by year(date),company
),
RAnkedCompanies as (

select year,
company,
total_laid_off,
DENSE_RANK() over(partition by year order by total_laid_off DESC)  as rnk
from companyYearlyLayOff
)

select * from RAnkedCompanies
where rnk<=5
order by year, rnk;


--31. Which industry saw the highest layoffs in each year? [nested CTEs, RANK]

with companymothly  as (select year(date) as year, 
       industry,
       sum(total_laid_off) as total_laid_off
from layoffs_staging
where date is not null and total_laid_off IS NOT NULL
group by  year(date) , 
       industry
),
rankedIndustry  as (

select *, 
       rank() OVER(partition by year order by total_laid_off DESC) as rnk 
from companymothly
)

select * from rankedIndustry where rnk = 1;

--32. Calculate month-over-month change in layoffs. [LAG()]

with monthlyLayOff as ( select year(date) as year, month(date) as month,
sum(total_laid_off) as current_month_laid_off
from layoffs_staging
where date is not null and total_laid_off is not null
group by YEAR(date), month(date)
)
select *, 
       lag(current_month_laid_off) over(order by year, month) as prev_month_laid_off,
       current_month_laid_off - lag(current_month_laid_off) over(order by year, month) as change_in_layoffs
from monthlyLayOff
order by year, month;

--33. Which companies laid off a lot even though they raised huge funding (layoffs per million raised)? [calculated column, NULLIF to avoid divide-by-zero]

select company,
       total_laid_off ,
       funds_raised_millions,
       cast(total_laid_off * 1.0 / nullif(funds_raised_millions,0) as Decimal(10,4)) as lay_off_per_million
from layoffs_staging
where total_laid_off is not null
and funds_raised_millions is not null
order by lay_off_per_million DESC;

--NULLIF(0,0) return null thats we used nullif here


--34. How many days passed between a company's first and last layoff? [self-join or MIN/MAX of date, DATEDIFF]

select company, 
       min(date) as first_layoff_date,
       max(date) as last_layofff_date,
       DATEDIFF(day, min(date), max(date)) as days_between_layoffs
from layoffs_staging
where date is not null
group by company
order by days_between_layoffs DESC;


--Phase 6: Business Problem and Insights

--Answer each of these in 2-3 sentences using your query results:
--35. Which industries should a recruiter focus on during a downturn, and which should they avoid?

select * from layoffs_staging
where total_laid_off IS NOT NULL

select industry,
       count(*) as lay_off_events,
       count(distinct company) as companies,
       sum(total_laid_off) as total_laid_off,
       round(avg(percentage_laid_off),2) as avg_laid_off
from layoffs_staging
where total_laid_off IS NOT NULL
group by industry
order by total_laid_off DESC;

select round((select count(*) from layoffs_staging where total_laid_off IS NULL)  * 100 / count(*), 2) from layoffs_staging ;

-- Under the assumption that recruiters want large pools of available talent, Consumer, Retail had the highest laid off 
--Industries like Legal,Energy, Aerospace,Fin-Tech,Manufacturing had few layoffs but also appears less in the datset 
--18% of rows were missing total_laid_off, so hring should be checked against job posting data


--36. What stage of company is safest to join, based on your data?

  SELECT ROUND(100 * SUM(case when  stage='Unknown' then 1 else 0 end) / COUNT(*), 1) AS pct_unknown_stage
  FROM layoffs_staging;

  select round((select count(*) from layoffs_staging where stage IS NULL)  * 100 / count(*), 2) from layoffs_staging ;


  select count(*)  from layoffs_staging where stage='Unknown';

  update layoffs_staging
  set stage=null
  where stage='NULL';

select stage,count(distinct company) as companies,
sum(total_laid_off) as total_laid_off,
round(sum(total_laid_off) / count(distinct company) , 0) as laid_off_per_company,
round(avg(percentage_laid_off)* 100,2) as avg_per_laid_off,
round(100 * sum(case when percentage_laid_off = 1 then 1 else 0 end) / count(*) , 1) as pct_event_shutdown
from layoffs_staging
group by stage
order by total_laid_off DESC;


--Stage Subsidiary is the safest because companies there cut the smallest share of their workforce on avg 5%.
--POST-IPO stage has the most total layoffs only because it has the most compnies

--37. If you were an investor, what warning signs appear before a company shuts down?

with company_summary as (select company,
       count(*) as layoffs_events,
       max(funds_raised_millions) as funds_raised,
       max(case when percentage_laid_off=1 then 1 else 0 end) as shut_down
from layoffs_staging
where funds_raised_millions IS NOT NULL
group by company)

select shut_down,
      count(*) as companies,
      round(avg(layoffs_events) ,2) as avg_layoffs_events,
      round(avg(funds_raised), 1) as avg_fund_raised
from company_summary
group by shut_down;

SELECT stage,
       COUNT(DISTINCT company) AS companies,
       ROUND(100 * COUNT(DISTINCT CASE WHEN percentage_laid_off = 1 THEN company END)
             / COUNT(DISTINCT company), 1) AS pct_shut_down
FROM layoffs_staging
GROUP BY stage
ORDER BY pct_shut_down DESC;

--Companies that shutdoen had lower funding on avg 133.4M
--and were most common at the seed stage  at 45%.
--Investors should be cautions of low fund raised and early stage seer or series a 


--38. What are the limitations of this dataset? (Missing values, news-reported only, biased toward tech)

--1.missing values - many rows have null total_laid_off, per_laid_off, date, industry, stage , funds_raised_million, so totals are probably undercounted.
--2.Only companies layoffs -here are no companies that never laid anyone off, so you can't say which type of company is "safe."
--3.Time period: the data covers only a few years (check with MIN and MAX of date), mostly the 2022-23 downturn.
--No company size or hiring data: you don't know total employees (apart from what percentage implies) and can't see who was hired.

SELECT COUNT(*) AS total_rows,
  ROUND(100.0 * SUM(CASE WHEN total_laid_off IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_null_total,
  ROUND(100.0 * SUM(CASE WHEN percentage_laid_off IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_null_percentage,
  ROUND(100.0 * SUM(CASE WHEN stage IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_null_stage,
  ROUND(100.0 * SUM(CASE WHEN funds_raised_millions IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_null_funds
FROM layoffs_staging;

select min(date), max(date) from layoffs_staging;

--This dataset has four main limitations
--First 20% of rows are missing total_laid_off, so totals are likely understated.
--Second, it only includes companies that had layoffs and were reported in the news, so it can't show which companies are safe.
--Third, the top industries (Finance, Healthcare, Retail, Transportation,Marketing) make up 50% of the rows so the results may not apply to other sectors.
--Finallay it covers only 2020 to 2023, mostly downturn period.

SELECT TOP 5 industry,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM layoffs_staging), 1) AS pct_of_rows
FROM layoffs_staging
GROUP BY industry
ORDER BY pct_of_rows DESC;
SELECT company,
       SUM(COALESCE(total_laid_off, 0)) AS total_laid_off
FROM layoffs_staging
GROUP BY company
having SUM(COALESCE(total_laid_off, 0)) =0




select count(*) from layoffs_staging where total_laid_off IS NULL;
select COUNT(*) from layoffs_staging where percentage_laid_off IS NULL;

--Phase 7: Stretch Goals
--Database-design normalization: split the table into companies, industries, locations, and layoff_events with primary and foreign keys. Rebuild your Question 24 result using joins.

select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME='layoffs_staging';

--Idustry table

CREATE TABLE industries (
    industry_id   INT IDENTITY(1,1) PRIMARY KEY,
    industry_name VARCHAR(100)
);

INSERT INTO industries (industry_name)
select distinct industry 
from layoffs_staging 
where industry is not null;

select * from industries;

--Loaction Table

create table locations(
location_id int identity(1,1) primary key,
location_name varchar(100),
country varchar(100)
);

Insert into locations(location_name, country)
select distinct location, country
from layoffs_staging;

select * from locations;

--Companies table 
CREATE TABLE companies (
    company_id   INT IDENTITY(1,1) PRIMARY KEY,
    company_name VARCHAR(200) NOT NULL UNIQUE
);


Insert into companies(company_name)
select distinct company
from layoffs_staging;


--
CREATE TABLE company_industries (
    company_id INT NOT NULL,
    industry_id INT NOT NULL,

    PRIMARY KEY (company_id, industry_id),

    FOREIGN KEY (company_id)
        REFERENCES companies(company_id),

    FOREIGN KEY (industry_id)
        REFERENCES industries(industry_id)
);

Insert into company_industries(company_id, industry_id)
SELECT DISTINCT
    c.company_id,
    i.industry_id
FROM layoffs_staging l
JOIN companies c
    ON c.company_name = l.company
JOIN industries i
    ON i.industry_name = l.industry
WHERE l.industry IS NOT NULL ;

select * from company_industries


--Below quer cause a problem
WITH ranked AS (
  SELECT company, industry,
         ROW_NUMBER() OVER (
             PARTITION BY company
             ORDER BY [date] DESC
         ) AS rn
  FROM layoffs_staging
  WHERE industry IS NOT NULL
)
INSERT INTO companies (company_name, industry_id)
SELECT s.company, i.industry_id
FROM (SELECT DISTINCT company FROM layoffs_staging) s
LEFT JOIN ranked r     ON r.company = s.company AND r.rn IN (1,2)
LEFT JOIN industries i ON i.industry_name = r.industry;



select s.company, i.industry_id
from (select company, (industry) as industry
      from layoffs_staging
    group by company) s
LEFT JOIN industries i on i.industry_name = s.industry
where industry_id IN (12,26) and company='Bolt';

drop table companies;


WITH ranked AS (
  SELECT company, industry,
         ROW_NUMBER() OVER (
             PARTITION BY company
             ORDER BY [date] DESC
         ) AS rn
  FROM layoffs_staging
  WHERE industry IS NOT NULL
)
SELECT company, industry
FROM ranked
WHERE rn IN (1, 2) and company='Aya';

select * from companies;

--Layoffs_event table
CREATE TABLE layoff_events (
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    company_id INT NOT NULL,
    industry_id INT NULL,
    location_id INT NULL,
    event_date DATE,
    total_laid_off INT,
    percentage_laid_off FLOAT,
    stage VARCHAR(50),
    funds_raised_millions FLOAT,

    FOREIGN KEY (company_id) REFERENCES companies(company_id),
    FOREIGN KEY (industry_id) REFERENCES industries(industry_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

drop table layoff_events;





INSERT INTO layoff_events
(
    company_id,
    industry_id,
    location_id,
    event_date,
    total_laid_off,
    percentage_laid_off,
    stage,
    funds_raised_millions
)
SELECT
    c.company_id,
    i.industry_id,
    l.location_id,
    s.[date],
    s.total_laid_off,
    s.percentage_laid_off,
    s.stage,
    s.funds_raised_millions
FROM layoffs_staging s
JOIN companies c
    ON c.company_name = s.company
LEFT JOIN industries i
    ON i.industry_name = s.industry
LEFT JOIN locations l
    ON l.location_name = s.location
   AND l.country = s.country;

                     select * from layoff_events;

SELECT company, COUNT(DISTINCT industry) AS n
FROM layoffs_staging
GROUP BY company
HAVING COUNT(DISTINCT industry) > 1;

SELECT *
FROM layoffs_staging
where company='Bolt';

select * from industries where industry_name IN ('Transportation','Finance')

SELECT *
FROM companies
where company_name='Bolt';

SELECT company_name, COUNT(DISTINCT industry) AS n
FROM layoffs_staging
GROUP BY company
HAVING COUNT(DISTINCT industry) > 1;



--Rebuild question 24 with joins
SELECT TOP 10
       c.company_name,
       SUM(e.total_laid_off) AS total_laid_off
FROM layoff_events e
JOIN companies c ON e.company_id = c.company_id
GROUP BY c.company_id, c.company_name
ORDER BY total_laid_off DESC;

select top 10 company, sum(total_laid_off) as total
from layoffs_staging
group by company
order by total DESC;

SELECT (SELECT COUNT(*) FROM layoffs_staging) AS staging_rows,
       (SELECT COUNT(*) FROM layoff_events)   AS event_rows;

--Create a view called v_layoffs_clean that other people can query.

select * from layoffs_staging where company ='Bolt'

CREATE VIEW v_layoffs_clean AS
SELECT
    le.event_id,
    c.company_name,
    i.industry_name,
    l.location_name,
    l.country,
    le.event_date,
    le.total_laid_off,
    le.percentage_laid_off,
    le.stage,
    le.funds_raised_millions
FROM layoff_events le
JOIN companies c
    ON le.company_id = c.company_id
LEFT JOIN industries i
    ON le.industry_id = i.industry_id
LEFT JOIN locations l
    ON le.location_id = l.location_id;


--Staging to cleaned dataset


select sum(total_laid_off) from layoffs_staging;

select count(distinct company) from layoffs_staging;

select count(*) from layoffs_staging;

select count(*) from layoffs_staging where percentage_laid_off=1;

SELECT COALESCE(stage, 'Unknown') AS stage,
       COUNT(DISTINCT company_name) AS companies,
       ROUND(AVG(percentage_laid_off) * 100, 1) AS avg_pct_cut
FROM v_layoffs_clean
WHERE percentage_laid_off IS NOT NULL
GROUP BY COALESCE(stage, 'Unknown')
ORDER BY avg_pct_cut DESC;


select top 50 company,sum(total_laid_off) as cn, max(funds_raised_millions) as max_raised
from layoffs_staging
where total_laid_off is not null and funds_raised_millions is not null
group by company
order by   cn  DESC;

select * from layoffs_staging

select stage, count(company) as cn, round(count(case when percentage_laid_off = 1 then 1 end) * 100.0 / count(*), 2 ) as shutdown_rate
from layoffs_staging
where percentage_laid_off is not null and stage is not null
group by stage
order by shutdown_rate DESC;

select stage, count(company) as cn
from layoffs_staging
where  stage is not null
group by stage


SELECT stage,
       COUNT(DISTINCT company) AS companies,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN percentage_laid_off = 1 THEN company END)
             / COUNT(distinct company), 2) AS shutdown_rate
FROM layoffs_staging
WHERE percentage_laid_off IS NOT NULL
GROUP BY stage;