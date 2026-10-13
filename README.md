📉 Global Layoffs Analysis | SQL Server + Power BI

End-to-end data analytics project: from a raw, messy layoffs dataset to a cleaned, normalized database and an interactive 2-page Power BI dashboard that answers real business questions.

<img width="613" height="316" alt="image" src="https://github.com/user-attachments/assets/706fd210-9d5b-4f1b-974e-f816cffe6e92" />

<img width="612" height="319" alt="image" src="https://github.com/user-attachments/assets/b10f799f-8b24-49c8-b869-30eaaf68bdae" />



📌 Table of Contents
🎯 Project Overview
❓ Business Questions
🗂️ Dataset
🛠️ Tools & Skills
🔄 Project Workflow
🧹 Data Cleaning
🏗️ Database Design (Normalization)
⚙️ Automation (Stored Procedure & View)
📊 Power BI Dashboard
💡 Key Insights
⚠️ Limitations
📁 Repository Structure
🚀 How to Run
🙋‍♀️ About Me
🎯 Project Overview

Layoffs dominated headlines from 2020 to 2023, but raw numbers alone don't tell a story. This project takes a raw layoffs dataset and:

🧹 Cleans and standardizes it in SQL Server
🏗️ Normalizes it into a relational schema (4 tables with primary and foreign keys)
🔎 Explores it with SQL to answer business questions
📊 Visualizes it in a 2-page Power BI dashboard (Overview + Risk & Deep Dive)

Goal: show how an analyst moves from messy data to decisions that a recruiter, investor, or business leader can act on.

❓ Business Questions
#	Question	Who cares?
1	Are layoffs getting better or worse over time?	Everyone
2	Which companies and industries were hit hardest?	Recruiters, analysts
3	Which funding stage is the riskiest?	Investors, job seekers
4	What warning signs appear before a company shuts down?	Investors
5	Do low-funded companies shut down more often?	Investors, founders
6	How do industries lay off (many small cuts or a few mega cuts)?	Business leaders
7	What are the limitations of this data?	Analysts
🗂️ Dataset

Public layoffs dataset (2020-2023) with one row per layoff event.

Column	Description
company	Company name
location	City
industry	Industry of the company
total_laid_off	Number of employees laid off
percentage_laid_off	Share of the workforce laid off (1 = 100%, a shutdown)
date	Date of the layoff
stage	Funding stage (Seed, Series A, Post-IPO, etc.)
country	Country
funds_raised_millions	Total funding raised in millions of USD
🛠️ Tools & Skills
Area	Details
🗄️ Database	Microsoft SQL Server
📊 BI Tool	Power BI Desktop
🧮 SQL skills	CTEs, window functions (ROW_NUMBER, DENSE_RANK, LAG), CASE WHEN, joins, views, stored procedures, transactions, error handling
🧠 DAX skills	Calculated columns, measures, CALCULATE, DIVIDE, DISTINCTCOUNT
🧹 Data skills	Data cleaning, standardization, normalization, EDA
🔄 Project Workflow
Raw CSV
   │
   ▼
layoffs_raw  ──►  layoffs_staging  (copy; raw data never edited)
                        │
                        ▼
          Clean + Standardize (SQL)
                        │
                        ▼
      Normalized tables (companies, industries,
          locations, layoff_events)
                        │
                        ▼
              v_layoffs_clean (view)
                        │
                        ▼
          Power BI Dashboard (2 pages)
🧹 Data Cleaning

All cleaning was done on a staging table, so the raw data stays untouched.

Step	What I did	SQL concepts
🗑️ Remove duplicates	Numbered identical rows and deleted the repeats	ROW_NUMBER() OVER (PARTITION BY ...), CTE
✂️ Standardize text	Trimmed spaces, unified variants like Crypto / Crypto Currency	TRIM, UPDATE, LIKE
🌍 Fix country names	Removed stray characters (e.g. trailing periods)	TRIM, REPLACE
📅 Fix dates	Converted text dates into a real DATE type	TRY_CONVERT, ALTER COLUMN
🕳️ Handle NULLs and blanks	Converted blanks to NULL, filled missing industries from other rows of the same company	self-join, UPDATE ... JOIN
🚫 Decide on unusable rows	Reviewed rows where both layoff columns were NULL and documented the decision	WHERE ... IS NULL

🧠 Why NULLs were NOT replaced with 0 or 1: NULL means "unknown", not "zero". Setting percentage_laid_off = 1 would wrongly label unknown rows as shutdowns, and setting total_laid_off = 0 would pull averages down. I kept NULLs and handled them in each query.

🏗️ Database Design (Normalization)

The flat table was split into 4 related tables to remove repeated text and prevent inconsistent updates.

industries                companies                  layoff_events
-------------             -------------              ---------------------
industry_id (PK)  ◄────   industry_id (FK)   ◄────   company_id (FK)
industry_name             company_id (PK)            event_id (PK)
                          company_name               location_id (FK) ──► locations
                                                     event_date           -------------
                                                     total_laid_off       location_id (PK)
                                                     percentage_laid_off  location
                                                     stage                country
                                                     funds_raised_millions
                                                     

<img width="565" height="367" alt="image" src="https://github.com/user-attachments/assets/f21ccb81-4351-46da-8725-01ed3668b179" />


Design decisions

✅ Each table has a primary key (IDENTITY(1,1)), and tables connect through foreign keys.
✅ stage and funds_raised_millions stay in layoff_events, because they change over time for the same company.
✅ Some companies (e.g. Bolt) appear under more than one industry. The companies table stores each company's most recent industry (ROW_NUMBER ordered by date), and this is documented as a known simplification.
⚙️ Automation (Stored Procedure & View)
🔁 usp_load_clean_from_staging

A stored procedure that reloads the clean tables from staging in one command:

Clears the child table first, then adds only missing industries, locations, and companies (NOT EXISTS)
Runs inside a transaction, so any error rolls everything back
Compares row counts between staging and layoff_events, and stops if they don't match
Safe to re-run after any cleaning change
sql
EXEC usp_load_clean_from_staging;
👁️ v_layoffs_clean

A view that joins all four tables into one flat, analyst-friendly table. It uses LEFT JOIN for industries and locations so events with missing values are not dropped. Power BI connects to this view.

sql
SELECT TOP 10 company_name, SUM(total_laid_off) AS total_laid_off
FROM v_layoffs_clean
GROUP BY company_name
ORDER BY total_laid_off DESC;
📊 Power BI Dashboard
📄 Page 1: Layoffs Overview

What happened?


Visual	Question answered
🔢 KPI cards	Total laid off, companies, layoff events, shutdowns
📈 Line chart	Are layoffs getting better or worse?
📊 Bar chart	Which companies laid off the most?
🥧 Pie chart + year slicer	Which industries had the most shutdowns in the selected year?
📊 Column chart	Which industries are hit hardest?
📊 Column chart	Which stage is safest?
📄 Page 2: Risk & Deep Dive

Why did it happen and where is the risk?


Visual	Question answered
🔢 KPI cards	Avg % workforce cut, shutdown rate, largest single layoff, avg laid off per event
📊 Column chart	Which year was worst?
🔵 Bubble scatter	Do low-funded companies shut down more?
📊 Bar chart	Which stage is truly riskiest (by shutdown rate)?
📊 100% stacked bar	How do industries lay off (by company size band)?
🟥 Treemap	Shutdown risk by funding and stage (box size = number of companies, color = shutdown rate)
📝 Insight box	Key takeaways in plain language
🧮 Helper columns and measures (DAX)
Name	Type	Purpose
Is Shutdown	Column	Flags rows with 100% layoff
Implied Headcount	Column	Estimates company size as total_laid_off ÷ percentage_laid_off
Size Band	Column	Groups companies: Under 100, 100-999, 1K-9.9K, 10K+, Unknown
Funding Band	Column	Groups funding: Under $10M, $10-50M, $50-200M, $200M+, Unknown
Shutdown Rate	Measure	Shutdown companies ÷ total companies
Avg Per Event	Measure	Total laid off ÷ number of layoff events
💡 Key Insights

Figures below are from the dashboard.

📉 383K employees were laid off across about 2K layoff events, and 115 companies shut down completely (7.06% shutdown rate).
📅 2022 was the worst year (about 81K laid off), followed by 2023 (about 48K). 2021 was the calmest (about 10K).
🏢 Amazon, Google, and Meta led in total layoffs (18.2K, 12.0K, and 11.0K), so a few giants drive a large share of the totals.
🏭 Consumer and Retail were the hardest-hit industries (about 45K and 44K laid off).
🗓️ April had the highest layoffs in a single month (24,879) and November the lowest (4,673).
🌱 Seed-stage companies showed the highest shutdown rate (43.14%), while Series D had the lowest (0.60%), which suggests early-stage companies carry the most risk. (Small groups were treated with caution, and the sample size is shown in tooltips.)
✂️ On average, companies cut 25.81% of their workforce per layoff event.
✅ Recommendations
For	Takeaway
🧑‍💼 Recruiters	Industries with the most layoffs (Consumer, Retail) have large pools of available talent.
💰 Investors	Check cash runway and funding early for Seed-stage companies, which showed the highest shutdown risk.
🎓 Job seekers	Later-stage and public companies showed lower shutdown rates, but can still make large cuts.
⚠️ Limitations
🕳️ Missing values: many rows have NULL total_laid_off, percentage_laid_off, stage, or funds_raised_millions, so totals are likely understated.
🎯 Only companies with layoffs: the data has no companies that never laid anyone off, so it can show risk patterns but not the probability of layoffs (selection bias).
📰 News-reported only: small and private companies may be missing.
💻 Tech-heavy: results may not apply to every industry.
⏳ Limited time window: 2020-2023, mostly a downturn period.
📏 Company size is estimated: Implied Headcount is calculated from percentages and is only available where both values exist.
🔁 Same-named companies: one industry per company is stored, so companies working in several industries are simplified.
📁 Repository Structure
📦 layoffs-analysis
 ┣ 📂 data
 ┃ ┗ 📄 layoffs.csv
 ┣ 📂 sql
 ┃ ┣ 📄 01_staging_and_cleaning.sql
 ┃ ┣ 📄 02_eda_queries.sql
 ┃ ┣ 📄 03_create_normalized_tables.sql
 ┃ ┣ 📄 04_stored_procedure.sql
 ┃ ┗ 📄 05_view_v_layoffs_clean.sql
 ┣ 📂 powerbi
 ┃ ┗ 📄 Layoffs_Dashboard.pbix
 ┣ 📂 images
 ┃ ┣ 📄 page1_overview.png
 ┃ ┗ 📄 page2_risk.png
 ┗ 📄 README.md
🚀 How to Run
📥 Import layoffs.csv into SQL Server as layoffs_raw.
▶️ Run the scripts in /sql in order (01 to 05).
🔁 Run the load procedure:
sql
   EXEC usp_load_clean_from_staging;
📊 Open Layoffs_Dashboard.pbix in Power BI Desktop.
🔌 Update the data source to your server, pointing to the v_layoffs_clean view, then Refresh.
🧠 What I Learned
Why you should always clean a staging copy and never the raw table
Why NULL should not be replaced with 0 or 1 just to fill gaps
Comparing rates, not totals: a group with more companies naturally has bigger totals
Always showing the sample size next to percentages (one company can only be 0% or 100%)
Designing a normalized schema and verifying it with row-count checks
Writing safe, re-runnable stored procedures with transactions
Telling a story with a dashboard: what happened on page 1, why and where is the risk on page 2



⭐ If you found this project useful, consider giving it a star!
