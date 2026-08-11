/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
===============================================================================
    EXEC Silver.load_silver;
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME2, @end_time DATETIME2, @layer_start_time DATETIME2, @layer_end_time DATETIME2;
	BEGIN TRY
		SET @layer_start_time =GETDATE();
			PRINT '===========================================================';
			PRINT 'Loading Bronze Layer';
			PRINT '===========================================================';
	-- CRM DATA SOURCE START
			PRINT '-----------------------------------------------------------';
			PRINT 'Loading CRM Tables';
			PRINT '-----------------------------------------------------------';
	-- crm_cust_info
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.crm_cust_info'
	TRUNCATE TABLE silver.crm_cust_info
	PRINT '>> Inserting Data Into: silver.crm_cust_info'
	INSERT INTO silver.crm_cust_info (
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date)
	SELECT 
	cst_id,
	cst_key,
	TRIM (cst_firstname) AS cst_firstname , -- Removes unwanted spaces in columns
	TRIM (cst_lastname) AS cst_lastname,

	CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single' --Changes to Uppercase, removes spaces and Switch Case statement to Transform Data (Data Normalisation and Standardisation)
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married' --Data Normalisation
		ELSE 'n/a' 
	END AS cst_marital_status,
	CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		ELSE 'n/a'
	END AS cst_gndr,
	cst_create_date
	FROM (
		SELECT *, -- Removes Duplicates using windows function(to rank the rows)
		ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
	)t WHERE flag_last = 1;
	SET @end_time =GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';

	-- crm_prd_info
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.crm_prd_info'
	TRUNCATE TABLE silver.crm_prd_info
	PRINT '>> Inserting Data Into: silver.crm_prd_info'
	INSERT INTO silver.crm_prd_info(
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt)
	SELECT
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-','_') AS cat_id,	-- Extracts a specific part of a string value using Subtring and replaces a specific value from the string using Replace
	SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, --Derived columns
	prd_nm,
	ISNULL(prd_cost, 0) AS prd_cost, -- Replaces NULL values with a specified replacement value using ISNULL
	CASE UPPER(TRIM(prd_line)) -- Another way to write the case statement
		WHEN 'M' THEN 'Mountain'
		WHEN 'R' THEN 'Road'
		WHEN 'S' THEN 'Other Sales'
		WHEN 'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,
	CAST(prd_start_dt AS DATE) AS prd_start_dt, --Cast changes the datatype.
	CAST(DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS DATE) AS prd_end_dt --Using Lead to access values from the next row withing a window. DATEADD adds or subtracts a specified number of days. 
	FROM bronze.crm_prd_info

	--Make sure to update the ddl script for the silver_layer, so the above can be inserted because of the new columns and changed datatypes.
	SET @end_time =GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';

	--crm_sales_details
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.crm_sales_details'
	TRUNCATE TABLE silver.crm_sales_details
	PRINT '>> Inserting Data Into: silver.crm_sales_details'
	INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price)
	SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL -- If sls_order_dt is 0 or lenght is not = 8 then change the value to NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) -- You can not cast from INT directly to DATE, you have to cast to varchar first in SQL Server
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL 
		ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL 
		ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) -- ABS returns absolute value i.e turn negative to positive numbers
			THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,  -- Recalculate sales if original value is missing or incorrect
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity, 0)  -- if sls_quantity is 0 then it changes to a NULL so we do not divide by 0 and break the code
		ELSE sls_price
	END AS sls_price --Recalculate price if original value is missing or incorrect
	FROM bronze.crm_sales_details;

	--Make sure to update the ddl script for the silver_layer, so the above can be inserted because of the new columns and changed datatypes.
	SET @end_time =GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';
	-- CRM DATA SOURCE END

	-- ERP DATA SOURCE START
	PRINT '-----------------------------------------------------------';
	PRINT 'Loading ERP Tables';
	PRINT '-----------------------------------------------------------';
	-- erp.cust_az12
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.erp_cust_az12'
	TRUNCATE TABLE silver.erp_cust_az12
	PRINT '>> Inserting Data Into: silver.erp_cust_az12'
	INSERT INTO silver.erp_cust_az12(
	cid,
	bdate,
	gen)
	SELECT
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- checks ifs id starts with NAS and trims it LEN(cid) makes the trim dynamic
		ELSE cid
	END cid,
	CASE WHEN bdate > GETDATE() THEN NULL --Checks if the birthday is higher than the current date, if so, the replaces with a NULL
		ELSE bdate
	END AS bdate,
	CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		 ELSE 'n/a'
	END AS gen
	FROM bronze.erp_cust_az12
	--If there are no changes to the ddl then you can insert into silver
	SET @end_time =GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';

	--erp.loc_a101
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.erp_loc_a101'
	TRUNCATE TABLE silver.erp_loc_a101
	PRINT '>> Inserting Data Into: silver.erp_loc_a101'
	INSERT INTO silver.erp_loc_a101(
	cid,
	cntry)
	SELECT
	REPLACE(cid, '-', '') AS cid,
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END AS cntry
	FROM bronze.erp_loc_a101
	--If there are no changes to the ddl then you can insert into silver
	SET @end_time =GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';

	-- erp_px_cat_g1v2
	SET @start_time =GETDATE();
	PRINT '>> Truncating Table: silver.erp_px_cat_g1v2'
	TRUNCATE TABLE silver.erp_px_cat_g1v2
	PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2'
	INSERT INTO silver.erp_px_cat_g1v2(
	id,
	cat,
	subcat,
	maintenance)
	SELECT
	id,
	cat,
	subcat,
	maintenance
	FROM bronze.erp_px_cat_g1v2;

	-- ERP DATA SOURCE END
	SET @end_time =GETDATE();
			PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
			PRINT '<><><><><><><><><><><><><><><<><><><><><><><><><><><><><><><>';
		
			SET @layer_end_time =GETDATE();
			PRINT '===========================================================';
			PRINT 'Silver Layer Load Complete';
			PRINT '>> Silver Layer Load Duration: ' + CAST(DATEDIFF(second, @layer_start_time, @layer_end_time) AS NVARCHAR) + ' seconds';
			PRINT '===========================================================';
	END TRY

	BEGIN CATCH
		PRINT '===========================================================';
		PRINT 'ERROR OCCURRED DURING LOADING OF THE SILVER LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '===========================================================';
	END CATCH
END
