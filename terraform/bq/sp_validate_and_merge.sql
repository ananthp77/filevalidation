CREATE OR REPLACE PROCEDURE  `ingestion.sp_validate_and_merge`()
BEGIN
  -- Step 1: Get the latest deduplicated records from staging
  CREATE OR REPLACE TABLE `ingestion.deduped_data` AS
  SELECT
    id,
    IF(name != CONCAT('User_', CAST(id AS STRING)), CONCAT('User_', CAST(id AS STRING)), name) AS name,
    email,
    age,
    country,
    signup_date,
    last_login,
    status,
    purchase_amount,
    membership_level
  FROM `ingestion.staging_data`
    qualify row_number() over (PARTITION BY id ORDER BY signup_date, last_login)=1;

  -- Step 2: Merge deduplicated data into final table
  MERGE `ingestion.final_data` T
  USING `ingestion.deduped_data` S
  ON T.id = S.id
  WHEN MATCHED THEN
    UPDATE SET
      name = S.name,
      email = S.email,
      age = S.age,
      country = S.country,
      signup_date = S.signup_date,
      last_login = S.last_login,
      status = S.status,
      purchase_amount = S.purchase_amount,
      membership_level = S.membership_level
  WHEN NOT MATCHED THEN
    INSERT (
      id, name, email, age, country, signup_date, last_login, status, purchase_amount, membership_level
    )
    VALUES (
      S.id, S.name, S.email, S.age, S.country, S.signup_date, S.last_login, S.status, S.purchase_amount, S.membership_level
    );
END;
