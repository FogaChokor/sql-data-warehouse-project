-- Table Join duplicate check customer dimension:
SELECT cst_id, COUNT(*) FROM
(SELECT
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ci.dwh_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
ON ci.cst_key = la.cid
) AS t GROUP BY cst_id
HAVING COUNT(*) > 1

--Gender Data Integration
SELECT DISTINCT
	ci.cst_gndr,
	ca.gen,
	CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the master source for gender info, so use it.
		ELSE COALESCE(ca.gen, 'n/a') --COALESCE replaces NULL with 'n/a'
	END AS new_gen
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
ON ci.cst_key = la.cid
ORDER BY 1,2 -- NULLs often come from joined tables if SQL finds no match


--Table Join duplicate check product dimension:
SELECT prd_key, COUNT(*) FROM(
SELECT
pn.prd_id,
pn.cat_id,
pn.prd_key,
pn.prd_nm,
pn.prd_cost,
pn.prd_line,
pn.prd_start_dt,
pc.cat,
pc.subcat,
pc.maintenance
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL --filters out all historical data. i.e current data does not have an end date yet so it will be null
) AS t GROUP BY prd_key
HAVING COUNT(*) > 1

-- Foreign Key Integrity (Dimensions)
-- Fact Checks: Checks if all dimension tables can successfully join to the fact table

SELECT *
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL

SELECT *
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL
