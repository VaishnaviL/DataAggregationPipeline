# Restaurant Data Warehouse Pipeline 

This project implements a data warehousing solution for a restaurant ecosystem. It integrates and processes data from various domains such as restaurant activity, orders, delivery-agent, delivery, and other data. The data follows a star schema architecture.

## Data Warehouse Design
Star Schema has a Fact Table that Stores transactional order data, including links to associated dimension tables.

Dimension Tables: restaurant_location, delivery_agent, menu, customer, restaurant, customer_address

## ETL Methodology
The ETL pipeline is structured into three layers, each residing in its own schema:

1. Staging Layer (stage_sch) : Load raw csv files 
2. Cleaning Layer (clean_sch) : Standardize and enrich raw data
3. Consumption Layer (Consumption_sch) : Create final analytical tables for reporting and business use
