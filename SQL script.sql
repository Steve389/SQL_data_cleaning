/*
Cleaning Data in SQL Queries
*/

SELECT * FROM Nashville_Housing_Dataset.nashville_housing_dataset;

----------------------------------------------------------------------------------------------------------------------------

-- 1. POPULATE PROPERTY ADDRESS

SELECT * 
FROM nashville_housing_dataset;

-- Across the dataset, there are null values in the PropertyAddress column. However, there is a pattern; the null values rows 
-- share the same ParcelID with a not null entry for PropertyAddress. If this is the case, we can do the following:
-- 1 --> Self join the table on the rows where the ParcelIDs are the same, the UniqueIDs are different and PropertyAddress is null.
-- 2--> Adding a column that takes the null values in Property Address and replaces them with the PropertyAddress values that have 
--      the same ParcelID
-- 3--> Updating the dataset so that the null values are replaced.

SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, IFNULL(a.PropertyAddress,b.PropertyAddress)
FROM Nashville_Housing_Dataset.nashville_housing_dataset a
JOIN Nashville_Housing_Dataset.nashville_housing_dataset b
ON a.ParcelID = b.ParcelID
AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress is null
;

UPDATE nashville_housing_dataset a
JOIN Nashville_Housing_Dataset.nashville_housing_dataset b
ON a.ParcelID = b.ParcelID
AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress,b.PropertyAddress)
WHERE a.PropertyAddress is null
;

----------------------------------------------------------------------------------------------------------------------------

-- 2. BREAKING OUT ADDRESS INTO INDIVIDUAL COLUMNS

-- First, let's have a look at the PropertyAddress column

SELECT PropertyAddress
FROM nashville_housing_dataset
;

-- This address is not very usable because it contains both the address and the city in the same comma-separated string.
-- Using SUBSTRING_INDEX, we can separate address and city in two different columns.

SELECT 
SUBSTRING_INDEX(PropertyAddress, ',', 1) as Address,
SUBSTRING_INDEX(PropertyAddress, ',', -1) as City
FROM nashville_housing_dataset
;

-- Now let's alter the dataset by adding the two columns PropertySplitAddress and PropertySplitCity.
-- After doing this, we will update these columns by populating them with the SUBSTRING_INDEX results from the previous query.

ALTER TABLE nashville_housing_dataset
ADD PropertySplitAddress nvarchar(255)
;
UPDATE nashville_housing_dataset
SET PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ',', 1)
;
ALTER TABLE nashville_housing_dataset
ADD PropertySplitCity nvarchar(255)
;
UPDATE nashville_housing_dataset
SET PropertySplitCity = SUBSTRING_INDEX(PropertyAddress, ',', -1)
;

-- If we select all the columns from the dataset, we can verify that the two columns have been added in the end.

SELECT *
FROM nashville_housing_dataset
;
-- Now let's check the column OwnerAddress. 
SELECT OwnerAddress
FROM nashville_housing_dataset
;

-- Also this column contains comma-separated strings.
-- However, in this case SUBSTRING_INDEX is impractical because there are more than two substrings separated by commas.
-- Since there is no MySQL built-in function that can split a delimited string, we will create a function from scratch.
-- Before doing that, we will have to enable the log_bin_trust_function_creators variable.

SET GLOBAL log_bin_trust_function_creators = 1;

CREATE FUNCTION SPLIT_STR(
  x VARCHAR(255),
  delim VARCHAR(12),
  pos INT
)
RETURNS VARCHAR(255)
RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
       LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
       delim, '');
       
-- Now we can use the function to split the OwnerAddress column into three separate columns

SELECT 
SPLIT_STR(OwnerAddress, ',',1) as Address,
SPLIT_STR(OwnerAddress, ',',2) as City,
SPLIT_STR(OwnerAddress, ',',3) as State
FROM nashville_housing_dataset
;

-- As before, let's alter the dataset by adding the two columns OwnerSplitAddress,OwnerSplitCity and OwnerSplitState.
-- After doing this, we will update these columns by populating them with the results from the previous query.

ALTER TABLE nashville_housing_dataset
Add OwnerSplitAddress Nvarchar(255)
;
UPDATE nashville_housing_dataset
SET OwnerSplitAddress = SPLIT_STR(OwnerAddress, ',',1)
;
ALTER TABLE nashville_housing_dataset
Add OwnerSplitCity Nvarchar(255)
;
UPDATE nashville_housing_dataset
SET OwnerSplitCity = SPLIT_STR(OwnerAddress, ',',2)
;
ALTER TABLE nashville_housing_dataset
Add OwnerSplitState Nvarchar(255)
;
UPDATE nashville_housing_dataset
SET OwnerSplitState = SPLIT_STR(OwnerAddress, ',',3)
;

-- Let's double check if all the columns have been properly added and populated.

SELECT * 
FROM nashville_housing_dataset
;

----------------------------------------------------------------------------------------------------------------------------

-- 3. CHANGE Y and N to Yes and No IN "Sold as Vacant" FIELD

SELECT SoldAsVacant, count(SoldAsVacant)
FROM nashville_housing_dataset
GROUP BY SoldAsVacant
ORDER BY count(SoldAsVacant)
;

-- This query shows that the SoldasVacant column contains the following values : 'Yes', 'No', 'Y' and 'N'. 
-- This goes against data uniformity, so we will remap the 'Y' and 'N' values to 'Yes' and 'No'.

SELECT SoldAsVacant
, CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END as RemappedValues
FROM nashville_housing_dataset
;

UPDATE nashville_housing_dataset
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	                    WHEN SoldAsVacant = 'N' THEN 'No'
	                    ELSE SoldAsVacant
	                END
;

----------------------------------------------------------------------------------------------------------------------------

-- 4. REMOVE DUPLICATES

-- First, let's use ROW_NUMBER over PARTITION BY to divide the rows into partitions by all columns. 
-- The row number will restart for each unique set of rows. In other words, row number 1 will equal to 
-- unique rows, while row number > 1 will equal to the duplicate rows. 

SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

FROM nashville_housing_dataset
;

-- Then, let's just select the row numbers > 1. To do this, we have to put the previous select statement into a CTE.

WITH RowNumCTE AS(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

FROM nashville_housing_dataset
)
SELECT *
FROM RowNumCTE
WHERE row_num > 1
ORDER BY PropertyAddress
;

-- The previous query showed 104 duplicate rows. Now let's delete them. Since MySQL doesn't support CTE-based delete, I will
-- have to join the original table with the CTE as a workaround.

WITH RowNumCTE AS(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

FROM nashville_housing_dataset
)
DELETE
FROM nashville_housing_dataset USING nashville_housing_dataset JOIN RowNumCTE ON nashville_housing_dataset.UniqueID = RowNumCTE.UniqueID
WHERE RowNumCTE.row_num > 1
;

----------------------------------------------------------------------------------------------------------------------------

-- 5. DELETE UNUSED COLUMNS

-- Let's delete columns that are not necessary.

ALTER TABLE nashville_housing_dataset
DROP COLUMN PropertyAddress, 
DROP COLUMN OwnerAddress, 
DROP COLUMN TaxDistrict
;


