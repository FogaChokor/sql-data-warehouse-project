-- Check For Nulls or Duplicates in Primary Key
-- Expectation: No Results

-- CRM DATA SOURCE START
-- crm_cust_info
SELECT * FROM bronze.crm_cust_info;

SELECT cst_id, COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL


-- Check for Unwanted Spaces
--Expectation: No Results
SELECT cst_firstname
From bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Data Standardization and Consistency
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info

SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info

-- Repeat above checks for new tables after interting into new table(silver)

/*
SELECT * FROM bronze.crm_cust_info;

SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL


-- Check for Unwanted Spaces
--Expectation: No Results
SELECT cst_firstname
From silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Data Standardization and Consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info

SELECT * FROM silver.crm_cust_info
*/


-- crm_prd_info
SELECT * FROM silver.crm_prd_info;

SELECT prd_id, COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for Unwanted Spaces
--Expectation: No Results
SELECT prd_nm
From bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check for NULLS or Negative Numbers
-- Expectation: No Results
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- Data Standardization and Consistency
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info

-- Check for Invalid Date Orders
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT
prd_id,
prd_key,
prd_nm,
prd_cost,
prd_line,
prd_start_dt,
prd_end_dt,
CAST(DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS DATE) AS prd_end_dt_test --Using Lead to access values from the next row withing a window. DATEADD adds or subtracts a specified number of days. Cast changes the datatype.
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509');

/*
SELECT
prd_id,
prd_key,
REPLACE(SUBSTRING(prd_key, 1, 5), '-','_') AS cat_id,	-- Extracts a specific part of a string value using Subtring and replaces a specific value from the string using Replace
prd_nm,
prd_cost,
prd_line,
prd_start_dt,
prd_end_dt
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-','_') NOT IN (SELECT distinct id FROM bronze.erp_px_cat_g1v2)
*/

--crm_sales_details

-- Check for Unwanted Spaces
--Expectation: No Results
SELECT 
sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);


-- Check Data Integrity Product key
--Expectation: No Results
SELECT 
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- Check Data Integrity customer id
--Expectation: No Results
SELECT 
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- Check for Invalid Date Format
SELECT 
NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt > 20500101 
OR sls_order_dt < 19000101
OR sls_order_dt <=0 
OR LEN(sls_order_dt) != 8

SELECT 
NULLIF(sls_ship_dt, 0) AS sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt > 20500101 
OR sls_ship_dt < 19000101
OR sls_ship_dt <=0 
OR LEN(sls_ship_dt) != 8

SELECT 
NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt > 20500101 
OR sls_due_dt < 19000101
OR sls_due_dt <=0 
OR LEN(sls_due_dt) != 8

-- Check for Invalid Date Orders
SELECT * FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt 
OR sls_order_dt > sls_due_dt
OR sls_ship_dt > sls_due_dt;

-- Check Data Consistency: Between Sales, Quantity and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero or negative

SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price


SELECT DISTINCT
sls_sales AS old_sls_sales,
sls_quantity,
sls_price AS old_sls_price,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) -- ABS returns absolute value i.e turn negative to positive numbers
		THEN sls_quantity * ABS(sls_price)
	ELSE sls_sales
END AS sls_sales,

CASE WHEN sls_price IS NULL OR sls_price <= 0
		THEN sls_sales / NULLIF(sls_quantity, 0)  -- if sls_quantity is 0 then it changes to a NULL so we do not divide by 0 and break the code
	ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

--Data quality check after insertion into silver(repeating the above checks)
SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

SELECT * FROM silver.crm_sales_details
-- CRM DATA SOURCE END

-- ERP DATA SOURCE START
SELECT * FROM bronze.erp_cust_az12
