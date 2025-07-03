use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

create or replace table stage_sch.orderitem (
    orderitemid text comment 'Primary Key (Source System)',              -- primary key as text
    orderid text comment 'Order FK(Source System)',                  -- foreign key reference as text (no constraint in snowflake)
    menuid text comment 'Menu FK(Source System)',                   -- foreign key reference as text (no constraint in snowflake)
    quantity text,                 -- quantity as text
    price text,                    -- price as text (no decimal constraint)
    subtotal text,                 -- subtotal as text (no decimal constraint)
    createddate text,              -- created date as text
    modifieddate text,             -- modified date as text

    -- audit columns with appropriate data types
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This is the order item stage/raw table where data will be copied from internal stage using copy command. This is as-is data represetation from the source location. All the columns are text data type except the audit columns that are added for traceability.';

create or replace stream stage_sch.orderitem_stm 
on table stage_sch.orderitem
append_only = true
comment = 'This is the append-only stream object on order item table that only gets delta data';

list @stage_sch.csv_stg/initial/order-item;

copy into stage_sch.orderitem (orderitemid, orderid, menuid, quantity, price, 
                     subtotal, createddate, modifieddate,
                     _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderitemid,
        t.$2::text as orderid,
        t.$3::text as menuid,
        t.$4::text as quantity,
        t.$5::text as price,
        t.$6::text as subtotal,
        t.$7::text as createddate,
        t.$8::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/order-items/ t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;

select * from stage_sch.orderitem;
select * from stage_sch.orderitem_stm;

CREATE OR REPLACE TABLE clean_sch.order_item (
    order_item_sk NUMBER AUTOINCREMENT primary key comment 'Surrogate Key (EDW)',    -- Auto-incremented unique identifier for each order item
    order_item_id NUMBER  NOT NULL UNIQUE comment 'Primary Key (Source System)',
    order_id_fk NUMBER  NOT NULL comment 'Order FK(Source System)',                  -- Foreign key reference for Order ID
    menu_id_fk NUMBER  NOT NULL comment 'Menu FK(Source System)',                   -- Foreign key reference for Menu ID
    quantity NUMBER(10, 2),                 -- Quantity as a decimal number
    price NUMBER(10, 2),                    -- Price as a decimal number
    subtotal NUMBER(10, 2),                 -- Subtotal as a decimal number
    created_dt TIMESTAMP,                 -- Created date of the order item
    modified_dt TIMESTAMP,                -- Modified date of the order item

    -- Audit columns
    _stg_file_name VARCHAR(255),            -- File name of the staging file
    _stg_file_load_ts TIMESTAMP,            -- Timestamp when the file was loaded
    _stg_file_md5 VARCHAR(255),             -- MD5 hash of the file for integrity check
    _copy_data_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when data is copied into the clean layer
)
comment = 'Order item entity under clean schema with appropriate data type under clean schema layer, data is populated using merge statement from the stage layer location table. This table does not support SCD2';

create or replace stream CLEAN_SCH.order_item_stm 
on table CLEAN_SCH.order_item
comment = 'This is the stream object on order_item table table to track insert, update, and delete changes';


select * from clean_sch.order_item_stm;


MERGE INTO clean_sch.order_item AS target
USING stage_sch.orderitem_stm AS source
ON  
    target.order_item_id = source.orderitemid and
    target.order_id_fk = source.orderid and
    target.menu_id_fk = source.menuid
WHEN MATCHED THEN
    -- Update the existing record with new data
    UPDATE SET 
        target.quantity = source.quantity,
        target.price = source.price,
        target.subtotal = source.subtotal,
        target.created_dt = source.createddate,
        target.modified_dt = source.modifieddate,
        target._stg_file_name = source._stg_file_name,
        target._stg_file_load_ts = source._stg_file_load_ts,
        target._stg_file_md5 = source._stg_file_md5,
        target._copy_data_ts = source._copy_data_ts
WHEN NOT MATCHED THEN
    -- Insert new record if no match is found
    INSERT (
        order_item_id,
        order_id_fk,
        menu_id_fk,
        quantity,
        price,
        subtotal,
        created_dt,
        modified_dt,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    )
    VALUES (
        source.orderitemid,
        source.orderid,
        source.menuid,
        source.quantity,
        source.price,
        source.subtotal,
        source.createddate,
        source.modifieddate,
        source._stg_file_name,
        source._stg_file_load_ts,
        source._stg_file_md5,
        CURRENT_TIMESTAMP()
    );


-- part-2
list @stage_sch.csv_stg/delta/order-items/;

copy into stage_sch.orderitem (orderitemid, orderid, menuid, quantity, price, 
                     subtotal, createddate, modifieddate,
                     _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderitemid,
        t.$2::text as orderid,
        t.$3::text as menuid,
        t.$4::text as quantity,
        t.$5::text as price,
        t.$6::text as subtotal,
        t.$7::text as createddate,
        t.$8::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/order-items/ t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;
Date Dimension — SQL

use role sysadmin;
use warehouse adhoc_wh;
use database sandbox;
use schema CONSUMPTION_SCH;


CREATE OR REPLACE TABLE CONSUMPTION_SCH.DATE_DIM (
    DATE_DIM_HK NUMBER PRIMARY KEY comment 'Menu Dim HK (EDW)',   -- Surrogate key for date dimension
    CALENDAR_DATE DATE UNIQUE,                     -- The actual calendar date
    YEAR NUMBER,                                   -- Year
    QUARTER NUMBER,                                -- Quarter (1-4)
    MONTH NUMBER,                                  -- Month (1-12)
    WEEK NUMBER,                                   -- Week of the year
    DAY_OF_YEAR NUMBER,                            -- Day of the year (1-365/366)
    DAY_OF_WEEK NUMBER,                            -- Day of the week (1-7)
    DAY_OF_THE_MONTH NUMBER,                       -- Day of the month (1-31)
    DAY_NAME STRING                                -- Name of the day (e.g., Monday)
)
comment = 'Date dimension table created using min of order data.';

insert into CONSUMPTION_SCH.DATE_DIM  
with recursive my_date_dim_cte as 
(
    -- anchor clause
    select 
        current_date() as today,
        year(today) as year,
        quarter(today) as quarter,
        month(today) as month,
        week(today) as week,
        dayofyear(today) as day_of_year,
        dayofweek(today) as day_of_week,
        day(today) as day_of_the_month,
        dayname(today) as day_name

    union all

     -- recursive clause
    select 
        dateadd('day', -1, today) as today_r,
        year(today_r) as year,
        quarter(today_r) as quarter,
        month(today_r) as month,
        week(today_r) as week,
        dayofyear(today_r) as day_of_year,
        dayofweek(today_r) as day_of_week,
        day(today_r) as day_of_the_month,
        dayname(today_r) as day_name
    from 
        my_date_dim_cte
    where 
        today_r > (select date(min(order_date)) from clean_sch.orders)
)
select 
    hash(SHA1_hex(today)) as DATE_DIM_HK,
    today ,                     -- The actual calendar date
    YEAR,                                   -- Year
    QUARTER,                                -- Quarter (1-4)
    MONTH,                                  -- Month (1-12)
    WEEK,                                   -- Week of the year
    DAY_OF_YEAR,                            -- Day of the year (1-365/366)
    DAY_OF_WEEK,                            -- Day of the week (1-7)
    DAY_OF_THE_MONTH,                       -- Day of the month (1-31)
    DAY_NAME     
from my_date_dim_cte;