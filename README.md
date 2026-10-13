



📉 Layoffs Analysis | SQL Server + Power BI

Cleaned a raw layoffs dataset (2020-2023) in SQL Server and built a 2-page Power BI dashboard to answer business questions.

🛠️ Tools
SQL Server (cleaning, normalization, view, stored procedure)
Power BI (dashboard, DAX)
🔄 What I Did
🧹 Cleaned the data in a staging table: removed duplicates, standardized text, fixed dates, handled NULLs
🏗️ Normalized it into 4 tables: companies, industries, locations, layoff_events
⚙️ Automated the load with a stored procedure and created a view v_layoffs_clean
📊 Built a dashboard with 2 pages
📊 Dashboard

Page 1: Layoffs Overview (what happened)

<img width="613" height="316" alt="image" src="https://github.com/user-attachments/assets/706fd210-9d5b-4f1b-974e-f816cffe6e92" />


Page 2: Risk & Deep Dive (why and where is the risk)


<img width="612" height="319" alt="image" src="https://github.com/user-attachments/assets/b10f799f-8b24-49c8-b869-30eaaf68bdae" />

💡 Key Insights
📉 383K people laid off, and 115 companies shut down (7.06% shutdown rate)
📅 2022 was the worst year (about 81K laid off)
🏢 Amazon, Google, and Meta had the most layoffs
🏭 Consumer and Retail were the hardest-hit industries
🌱 Seed-stage companies had the highest shutdown rate (43.14%)
⚠️ Limitations


Data only includes companies with reported layoffs
Many rows have missing values, so totals may be understated
Mostly tech companies, and only 2020-2023


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


🚀 How to Run
Import the CSV into SQL Server
Run the scripts in the sql folder in order
Run EXEC usp_load_clean_from_staging;
Open the .pbix file and refresh
🙋‍♀️ About Me

Sakshi Dhobale, Mumbai 📍 Moving into a Data Analyst / SQL Analyst role. 🔗 LinkedIn | 🐙 GitHub

