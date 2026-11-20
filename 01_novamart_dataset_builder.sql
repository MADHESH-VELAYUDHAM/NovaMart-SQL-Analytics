/* ==================================================================
   NOVAMART ANALYTICS WAREHOUSE  —  DATASET BUILDER
   Pumo Training Institute | Advanced SQL Pattern Practice
   Target : MySQL 8.0+
   ------------------------------------------------------------------
   WHAT THIS BUILDS
     dim_store              60 rows
     dim_product         2,000 rows
     dim_customer      200,000 rows
     fact_sales     10,000,000 rows   <-- the headline table
     web_events      2,000,000 rows   (sessionization)
     customer_logins ~1,500,000 rows  (gaps & islands)
     stg_customer_records ~400,000    (deduplication, has dirty copies)

   SCALE CONTROL  -- set @SCALE before running.
     @SCALE = 1     ->    100,000 sales   (~20 sec)   laptop / classroom
     @SCALE = 10    ->  1,000,000 sales   (~2 min)    practice
     @SCALE = 100   -> 10,000,000 sales   (~15-25 min) FULL BUILD
   All other tables scale in proportion.

   DETERMINISTIC: uses CRC32 hashing, not RAND().
   Every student who runs this gets byte-identical data, so answer
   keys match everywhere. Re-running gives the same numbers.
   ================================================================== */

/* ---------- 0. SESSION SETUP ---------- */
SET @SCALE = 100;                 -- <<<< CHANGE THIS ONE NUMBER

SET SESSION cte_max_recursion_depth = 1000000;
SET SESSION unique_checks = 0;
SET SESSION foreign_key_checks = 0;
SET SESSION autocommit = 1;

DROP DATABASE IF EXISTS novamart;
CREATE DATABASE novamart DEFAULT CHARACTER SET utf8mb4;
USE novamart;

/* ---------- 1. NUMBERS HELPER ----------
   A 0-9 digit table cross-joined six times = 1,000,000 integers.
   Do NOT use a recursive CTE here: cte_max_recursion_depth
   defaults to 1000 and this is the portable, fast way.          */

CREATE TABLE digits (d TINYINT UNSIGNED NOT NULL PRIMARY KEY);
INSERT INTO digits VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

CREATE TABLE nums (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO nums (n)
SELECT a.d + b.d*10 + c.d*100 + e.d*1000 + f.d*10000 + g.d*100000
FROM digits a, digits b, digits c, digits e, digits f, digits g;
-- nums now holds 0 .. 999999

/* ---------- 2. DIMENSION: STORES (60) ---------- */
CREATE TABLE dim_store (
  store_id      SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
  store_name    VARCHAR(60)  NOT NULL,
  city          VARCHAR(40)  NOT NULL,
  state         VARCHAR(40)  NOT NULL,
  region        VARCHAR(10)  NOT NULL,
  store_format  VARCHAR(20)  NOT NULL,
  opened_date   DATE         NOT NULL
) ENGINE=InnoDB;

INSERT INTO dim_store (store_id, store_name, city, state, region, store_format, opened_date)
SELECT
  n.n + 1,
  CONCAT('NovaMart ', ct.city, ' #', LPAD(n.n + 1, 3, '0')),
  ct.city, ct.state, ct.region,
  ELT(1 + (n.n % 3), 'Hypermarket', 'Supermarket', 'Express'),
  DATE_ADD('2015-01-01', INTERVAL (CRC32(CONCAT('st', n.n)) % 3000) DAY)
FROM nums n
JOIN (
  SELECT 0 AS k,'Chennai' AS city,'Tamil Nadu' AS state,'South' AS region UNION ALL
  SELECT 1,'Coimbatore','Tamil Nadu','South'      UNION ALL
  SELECT 2,'Madurai','Tamil Nadu','South'         UNION ALL
  SELECT 3,'Bengaluru','Karnataka','South'        UNION ALL
  SELECT 4,'Hyderabad','Telangana','South'        UNION ALL
  SELECT 5,'Kochi','Kerala','South'               UNION ALL
  SELECT 6,'Mumbai','Maharashtra','West'          UNION ALL
  SELECT 7,'Pune','Maharashtra','West'            UNION ALL
  SELECT 8,'Ahmedabad','Gujarat','West'           UNION ALL
  SELECT 9,'Delhi','Delhi','North'                UNION ALL
  SELECT 10,'Jaipur','Rajasthan','North'          UNION ALL
  SELECT 11,'Lucknow','Uttar Pradesh','North'     UNION ALL
  SELECT 12,'Kolkata','West Bengal','East'        UNION ALL
  SELECT 13,'Patna','Bihar','East'                UNION ALL
  SELECT 14,'Bhubaneswar','Odisha','East'
) ct ON ct.k = n.n % 15
WHERE n.n < 60;

/* ---------- 3. DIMENSION: PRODUCTS (2,000) ---------- */
CREATE TABLE dim_product (
  product_id    MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY,
  product_name  VARCHAR(80) NOT NULL,
  category      VARCHAR(30) NOT NULL,
  sub_category  VARCHAR(40) NOT NULL,
  brand         VARCHAR(30) NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL,
  cost_price    DECIMAL(10,2) NOT NULL,
  INDEX ix_prod_cat (category, sub_category)
) ENGINE=InnoDB;

INSERT INTO dim_product (product_id, product_name, category, sub_category, brand, unit_price, cost_price)
SELECT
  n.n + 1,
  CONCAT(cat.sub_category, ' ', br.brand, ' ', LPAD(n.n + 1, 4, '0')),
  cat.category, cat.sub_category, br.brand,
  ROUND(cat.base_price * (0.55 + (CRC32(CONCAT('pp', n.n)) % 1000) / 1000.0 * 1.5), 2),
  ROUND(cat.base_price * (0.55 + (CRC32(CONCAT('pp', n.n)) % 1000) / 1000.0 * 1.5)
        * (0.55 + (CRC32(CONCAT('cp', n.n)) % 250) / 1000.0), 2)
FROM nums n
JOIN (
  SELECT 0 AS k,'Electronics' AS category,'Mobile Phones' AS sub_category, 24000 AS base_price UNION ALL
  SELECT 1,'Electronics','Laptops',       58000 UNION ALL
  SELECT 2,'Electronics','Audio',          3200 UNION ALL
  SELECT 3,'Electronics','Televisions',   42000 UNION ALL
  SELECT 4,'Groceries','Staples',           420 UNION ALL
  SELECT 5,'Groceries','Beverages',         180 UNION ALL
  SELECT 6,'Groceries','Snacks',            140 UNION ALL
  SELECT 7,'Groceries','Dairy',              95 UNION ALL
  SELECT 8,'Apparel','Menswear',           1450 UNION ALL
  SELECT 9,'Apparel','Womenswear',         1850 UNION ALL
  SELECT 10,'Apparel','Kidswear',           780 UNION ALL
  SELECT 11,'Apparel','Footwear',          2200 UNION ALL
  SELECT 12,'Home & Kitchen','Cookware',    1650 UNION ALL
  SELECT 13,'Home & Kitchen','Furniture',   8900 UNION ALL
  SELECT 14,'Home & Kitchen','Decor',        640 UNION ALL
  SELECT 15,'Beauty','Skincare',             520 UNION ALL
  SELECT 16,'Beauty','Haircare',             340 UNION ALL
  SELECT 17,'Beauty','Fragrance',           1900 UNION ALL
  SELECT 18,'Sports','Fitness',             2400 UNION ALL
  SELECT 19,'Sports','Outdoor',             3100
) cat ON cat.k = n.n % 20
JOIN (
  SELECT 0 AS bk,'Aurora' AS brand UNION ALL SELECT 1,'Zenith'  UNION ALL
  SELECT 2,'Vega'         UNION ALL SELECT 3,'Kavin'   UNION ALL
  SELECT 4,'Nimbus'       UNION ALL SELECT 5,'Orion'   UNION ALL
  SELECT 6,'Meridian'     UNION ALL SELECT 7,'Solace'  UNION ALL
  SELECT 8,'Tarang'       UNION ALL SELECT 9,'Everest'
) br ON br.bk = (n.n DIV 20) % 10
WHERE n.n < 2000;

/* ---------- 4. DIMENSION: CUSTOMERS (200,000 at SCALE=100) ----------
   signup_date is spread over the window and drives cohort analysis. */
CREATE TABLE dim_customer (
  customer_id     INT UNSIGNED NOT NULL PRIMARY KEY,
  customer_name   VARCHAR(60) NOT NULL,
  city            VARCHAR(40) NOT NULL,
  state           VARCHAR(40) NOT NULL,
  region          VARCHAR(10) NOT NULL,
  signup_date     DATE        NOT NULL,
  membership_tier VARCHAR(10) NOT NULL,
  birth_year      SMALLINT    NULL,
  INDEX ix_cust_signup (signup_date),
  INDEX ix_cust_tier (membership_tier)
) ENGINE=InnoDB;

SET @N_CUST = GREATEST(2000, @SCALE * 2000);

INSERT INTO dim_customer
  (customer_id, customer_name, city, state, region, signup_date, membership_tier, birth_year)
SELECT
  s.n + 1,
  CONCAT(fn.first_name, ' ', ln.last_name),
  ct.city, ct.state, ct.region,
  /* signups spread 2022-07-01 .. 2026-06-30, denser in recent months */
  DATE_ADD('2022-07-01', INTERVAL
    FLOOR(POW((CRC32(CONCAT('sg', s.n)) % 10000) / 10000.0, 0.75) * 1460) DAY),
  ELT(1 + CASE
        WHEN (CRC32(CONCAT('tr', s.n)) % 100) < 55 THEN 0
        WHEN (CRC32(CONCAT('tr', s.n)) % 100) < 82 THEN 1
        WHEN (CRC32(CONCAT('tr', s.n)) % 100) < 96 THEN 2
        ELSE 3 END,
      'Bronze','Silver','Gold','Platinum'),
  /* ~4% NULL birth_year on purpose: teaches NULL handling */
  CASE WHEN (CRC32(CONCAT('by', s.n)) % 100) < 4 THEN NULL
       ELSE 1960 + (CRC32(CONCAT('by', s.n)) % 45) END
FROM (
  SELECT a.n + b.n * 1000000 AS n
  FROM nums a
  CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1) b
) s
JOIN (
  SELECT 0 AS k,'Chennai' AS city,'Tamil Nadu' AS state,'South' AS region UNION ALL
  SELECT 1,'Coimbatore','Tamil Nadu','South'  UNION ALL
  SELECT 2,'Madurai','Tamil Nadu','South'     UNION ALL
  SELECT 3,'Bengaluru','Karnataka','South'    UNION ALL
  SELECT 4,'Hyderabad','Telangana','South'    UNION ALL
  SELECT 5,'Kochi','Kerala','South'           UNION ALL
  SELECT 6,'Mumbai','Maharashtra','West'      UNION ALL
  SELECT 7,'Pune','Maharashtra','West'        UNION ALL
  SELECT 8,'Ahmedabad','Gujarat','West'       UNION ALL
  SELECT 9,'Delhi','Delhi','North'            UNION ALL
  SELECT 10,'Jaipur','Rajasthan','North'      UNION ALL
  SELECT 11,'Lucknow','Uttar Pradesh','North' UNION ALL
  SELECT 12,'Kolkata','West Bengal','East'    UNION ALL
  SELECT 13,'Patna','Bihar','East'            UNION ALL
  SELECT 14,'Bhubaneswar','Odisha','East'
) ct ON ct.k = (CRC32(CONCAT('cc', s.n)) % 15)
JOIN (
  SELECT 0 AS fk,'Arun' AS first_name UNION ALL SELECT 1,'Priya'    UNION ALL
  SELECT 2,'Karthik'  UNION ALL SELECT 3,'Divya'     UNION ALL
  SELECT 4,'Rahul'    UNION ALL SELECT 5,'Sneha'     UNION ALL
  SELECT 6,'Vikram'   UNION ALL SELECT 7,'Ananya'    UNION ALL
  SELECT 8,'Suresh'   UNION ALL SELECT 9,'Meera'     UNION ALL
  SELECT 10,'Naveen'  UNION ALL SELECT 11,'Lakshmi'  UNION ALL
  SELECT 12,'Ravi'    UNION ALL SELECT 13,'Kavya'    UNION ALL
  SELECT 14,'Manish'  UNION ALL SELECT 15,'Ishita'
) fn ON fn.fk = (CRC32(CONCAT('fn', s.n)) % 16)
JOIN (
  SELECT 0 AS lk,'Kumar' AS last_name UNION ALL SELECT 1,'Sharma'   UNION ALL
  SELECT 2,'Iyer'      UNION ALL SELECT 3,'Reddy'     UNION ALL
  SELECT 4,'Nair'      UNION ALL SELECT 5,'Patel'     UNION ALL
  SELECT 6,'Menon'     UNION ALL SELECT 7,'Gupta'     UNION ALL
  SELECT 8,'Rao'       UNION ALL SELECT 9,'Krishnan'  UNION ALL
  SELECT 10,'Verma'    UNION ALL SELECT 11,'Pillai'
) ln ON ln.lk = (CRC32(CONCAT('ln', s.n)) % 12)
WHERE s.n < @N_CUST;


/* ==================================================================
   5. FACT_SALES  —  the headline table
   ------------------------------------------------------------------
   Built in batches of 100,000. Indexes are added AFTER the load
   (building them during the load roughly triples the time).
   ================================================================== */

CREATE TABLE fact_sales (
  sale_id       BIGINT UNSIGNED NOT NULL,
  sale_ts       DATETIME        NOT NULL,
  sale_date     DATE            NOT NULL,
  store_id      SMALLINT UNSIGNED NOT NULL,
  product_id    MEDIUMINT UNSIGNED NOT NULL,
  customer_id   INT UNSIGNED    NOT NULL,
  quantity      SMALLINT UNSIGNED NOT NULL,
  unit_price    DECIMAL(10,2)   NOT NULL,
  discount_pct  DECIMAL(5,2)    NULL,
  net_amount    DECIMAL(12,2)   NOT NULL,
  payment_mode  VARCHAR(12)     NOT NULL,
  order_status  VARCHAR(12)     NOT NULL,
  channel       VARCHAR(10)     NOT NULL,
  PRIMARY KEY (sale_id)
) ENGINE=InnoDB;

DROP PROCEDURE IF EXISTS build_sales;
DELIMITER $$
CREATE PROCEDURE build_sales(IN p_batches INT, IN p_ncust INT)
BEGIN
  DECLARE b INT DEFAULT 0;
  WHILE b < p_batches DO
    INSERT INTO fact_sales
      (sale_id, sale_ts, sale_date, store_id, product_id, customer_id,
       quantity, unit_price, discount_pct, net_amount,
       payment_mode, order_status, channel)
    SELECT
      g.rid + 1                                        AS sale_id,
      TIMESTAMP(g.d, SEC_TO_TIME(g.secs))              AS sale_ts,
      g.d                                              AS sale_date,
      g.store_id, g.product_id, g.customer_id,
      g.quantity, p.unit_price, g.discount_pct,
      ROUND(g.quantity * p.unit_price
            * (1 - COALESCE(g.discount_pct, 0) / 100), 2) AS net_amount,
      g.payment_mode, g.order_status, g.channel
    FROM (
      SELECT
        rid,
        /* ---- DATE: growth trend + Oct/Nov festival spike + weekend lift ---- */
        CASE
          /* 12% pulled into the Oct-Nov festival window, but never before signup */
          WHEN hf < 12
           AND DATE_ADD(MAKEDATE(2023 + (hf2 % 3), 274), INTERVAL (hf3 % 46) DAY) >= window_open
            THEN DATE_ADD(MAKEDATE(2023 + (hf2 % 3), 274), INTERVAL (hf3 % 46) DAY)
          /* 18% nudged FORWARD to the coming Saturday (forward only, so we
             can never slip back behind window_open) */
          WHEN hw < 18
            THEN DATE_ADD(base_d, INTERVAL ((5 - WEEKDAY(base_d) + 7) % 7) DAY)
          ELSE base_d
        END AS d,
        /* ---- TIME OF DAY: bimodal, lunch + evening peaks ---- */
        CASE WHEN hh < 55 THEN 61200 + (hs % 12600)   -- 17:00-20:30 evening peak
             WHEN hh < 78 THEN 43200 + (hs % 9000)    -- 12:00-14:30 lunch
             ELSE 32400 + (hs % 68400) % 50400        -- spread across the day
        END AS secs,
        store_id, product_id, customer_id, quantity,
        discount_pct, payment_mode, order_status, channel
      FROM (
        SELECT
          r.*,
          /* A customer cannot buy before they signed up. The purchase window
             opens at the later of their signup and the start of the data era,
             and closes at 2026-06-30. Offsets are recent-heavy (growth trend). */
          DATE_ADD(r.window_open, INTERVAL
            FLOOR(POW(r.u_date / 100000.0, 0.82)
                  * GREATEST(DATEDIFF('2026-06-30', r.window_open), 1)) DAY) AS base_d
        FROM (
        SELECT
          (b_no * 100000) + n.n AS rid,
          GREATEST(c.signup_date, DATE '2023-01-01') AS window_open,
          c.signup_date,
          CRC32(CONCAT('dt', b_no, '_', n.n)) % 100000 AS u_date,
          CRC32(CONCAT('fs', b_no, '_', n.n)) % 100 AS hf,
          CRC32(CONCAT('f2', b_no, '_', n.n)) % 100 AS hf2,
          CRC32(CONCAT('f3', b_no, '_', n.n)) % 100 AS hf3,
          CRC32(CONCAT('wk', b_no, '_', n.n)) % 100 AS hw,
          CRC32(CONCAT('hh', b_no, '_', n.n)) % 100 AS hh,
          CRC32(CONCAT('hs', b_no, '_', n.n))       AS hs,
          /* flagship stores sell more -> mild skew toward low store_id */
          1 + FLOOR(POW((CRC32(CONCAT('sr', b_no, '_', n.n)) % 10000) / 10000.0, 1.30) * 60)
              AS store_id,
          /* bestseller skew: a minority of SKUs carry most volume */
          1 + FLOOR(POW((CRC32(CONCAT('pd', b_no, '_', n.n)) % 10000) / 10000.0, 1.65) * 2000)
              AS product_id,
          /* Pareto customers: loyal early-signup base buys far more */
          1 + FLOOR(POW((CRC32(CONCAT('cu', b_no, '_', n.n)) % 100000) / 100000.0, 2.40) * p_ncust)
              AS customer_id,
          1 + CASE WHEN (CRC32(CONCAT('qt', b_no, '_', n.n)) % 100) < 62 THEN 0
                   WHEN (CRC32(CONCAT('qt', b_no, '_', n.n)) % 100) < 85 THEN 1
                   WHEN (CRC32(CONCAT('qt', b_no, '_', n.n)) % 100) < 95 THEN 2
                   ELSE 3 + (CRC32(CONCAT('q2', b_no, '_', n.n)) % 5) END AS quantity,
          /* ~9% NULL discount on purpose: forces COALESCE / NULL-safe thinking */
          CASE WHEN (CRC32(CONCAT('dc', b_no, '_', n.n)) % 100) < 9 THEN NULL
               WHEN (CRC32(CONCAT('dc', b_no, '_', n.n)) % 100) < 46 THEN 0.00
               ELSE ROUND(2.5 + (CRC32(CONCAT('d2', b_no, '_', n.n)) % 3000) / 100.0, 2)
          END AS discount_pct,
          ELT(1 + CASE
                WHEN (CRC32(CONCAT('pm', b_no, '_', n.n)) % 100) < 42 THEN 0
                WHEN (CRC32(CONCAT('pm', b_no, '_', n.n)) % 100) < 66 THEN 1
                WHEN (CRC32(CONCAT('pm', b_no, '_', n.n)) % 100) < 84 THEN 2
                WHEN (CRC32(CONCAT('pm', b_no, '_', n.n)) % 100) < 93 THEN 3
                ELSE 4 END,
              'UPI','Card','Cash','NetBanking','Wallet') AS payment_mode,
          ELT(1 + CASE
                WHEN (CRC32(CONCAT('os', b_no, '_', n.n)) % 100) < 76 THEN 0
                WHEN (CRC32(CONCAT('os', b_no, '_', n.n)) % 100) < 85 THEN 1
                WHEN (CRC32(CONCAT('os', b_no, '_', n.n)) % 100) < 92 THEN 2
                ELSE 3 END,
              'completed','cancelled','pending','returned') AS order_status,
          ELT(1 + CASE
                WHEN (CRC32(CONCAT('ch', b_no, '_', n.n)) % 100) < 55 THEN 0
                WHEN (CRC32(CONCAT('ch', b_no, '_', n.n)) % 100) < 82 THEN 1
                ELSE 2 END,
              'Store','App','Web') AS channel
        FROM nums n CROSS JOIN (SELECT b AS b_no) bb
        JOIN dim_customer c
          ON c.customer_id =
             1 + FLOOR(POW((CRC32(CONCAT('cu', b_no, '_', n.n)) % 100000) / 100000.0, 2.40) * p_ncust)
        WHERE n.n < 100000
        ) r
      ) raw
    ) g
    JOIN dim_product p ON p.product_id = g.product_id;

    SET b = b + 1;
    DO SLEEP(0);          -- yields between batches, keeps the undo log small
  END WHILE;
END$$
DELIMITER ;

CALL build_sales(@SCALE, @N_CUST);
DROP PROCEDURE build_sales;

/* ---- indexes AFTER the load ---- */
CREATE INDEX ix_fs_date      ON fact_sales (sale_date);
CREATE INDEX ix_fs_cust_date ON fact_sales (customer_id, sale_date);
CREATE INDEX ix_fs_prod      ON fact_sales (product_id);
CREATE INDEX ix_fs_store     ON fact_sales (store_id, sale_date);
CREATE INDEX ix_fs_status    ON fact_sales (order_status);

/* ==================================================================
   6. CUSTOMER_LOGINS  — engineered so real streaks exist
   ------------------------------------------------------------------
   Rows are emitted as BLOCKS of consecutive days (length 1-14) with
   genuine gaps in between, so Gaps-and-Islands has something to find.
   A UNIQUE key + INSERT IGNORE collapses overlapping blocks.
   ================================================================== */

CREATE TABLE customer_logins (
  customer_id INT UNSIGNED NOT NULL,
  login_date  DATE         NOT NULL,
  device      VARCHAR(10)  NOT NULL,
  PRIMARY KEY (customer_id, login_date)
) ENGINE=InnoDB;

DROP PROCEDURE IF EXISTS build_logins;
DELIMITER $$
CREATE PROCEDURE build_logins(IN p_batches INT, IN p_ncust INT)
BEGIN
  DECLARE b INT DEFAULT 0;
  WHILE b < p_batches DO
    INSERT IGNORE INTO customer_logins (customer_id, login_date, device)
    SELECT
      blk.customer_id,
      DATE_ADD(blk.start_date, INTERVAL d.n DAY),
      ELT(1 + ((blk.customer_id + d.n) % 3), 'Android', 'iOS', 'Desktop')
    FROM (
      SELECT
        1 + FLOOR(POW((CRC32(CONCAT('lc', b_no, '_', n.n)) % 100000) / 100000.0, 1.9) * p_ncust)
            AS customer_id,
        DATE_ADD('2025-01-01', INTERVAL (CRC32(CONCAT('ld', b_no, '_', n.n)) % 540) DAY)
            AS start_date,
        1 + (CRC32(CONCAT('ll', b_no, '_', n.n)) % 14) AS streak_len
      FROM nums n CROSS JOIN (SELECT b AS b_no) bb
      WHERE n.n < 3000
    ) blk
    JOIN nums d ON d.n < blk.streak_len;
    SET b = b + 1;
  END WHILE;
END$$
DELIMITER ;

CALL build_logins(@SCALE, @N_CUST);
DROP PROCEDURE build_logins;

CREATE INDEX ix_lg_date ON customer_logins (login_date);

/* ==================================================================
   7. WEB_EVENTS  — engineered so real sessions exist
   ------------------------------------------------------------------
   Within a session, gaps are 2-8 minutes (< 30 min cut-off).
   Between sessions, gaps are at least ~2 hours (> 30 min cut-off).
   So a 30-minute sessionization rule finds exactly the intended runs.
   ================================================================== */

CREATE TABLE web_events (
  event_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  event_ts    DATETIME     NOT NULL,
  event_type  VARCHAR(16)  NOT NULL,
  page_url    VARCHAR(60)  NOT NULL,
  device      VARCHAR(10)  NOT NULL,
  INDEX ix_we_cust_ts (customer_id, event_ts)
) ENGINE=InnoDB;

DROP PROCEDURE IF EXISTS build_events;
DELIMITER $$
CREATE PROCEDURE build_events(IN p_batches INT, IN p_ncust INT)
BEGIN
  DECLARE b INT DEFAULT 0;
  WHILE b < p_batches DO
    INSERT INTO web_events (customer_id, event_ts, event_type, page_url, device)
    SELECT
      s.customer_id,
      s.session_start + INTERVAL (e.n * s.gap_min) MINUTE,
      ELT(1 + CASE WHEN e.n = 0 THEN 0
                   WHEN (CRC32(CONCAT('et', s.sid, '_', e.n)) % 100) < 46 THEN 1
                   WHEN (CRC32(CONCAT('et', s.sid, '_', e.n)) % 100) < 72 THEN 2
                   WHEN (CRC32(CONCAT('et', s.sid, '_', e.n)) % 100) < 89 THEN 3
                   ELSE 4 END,
          'landing','product_view','search','add_to_cart','checkout'),
      CONCAT('/p/', 1 + (CRC32(CONCAT('pg', s.sid, '_', e.n)) % 2000)),
      s.device
    FROM (
      SELECT
        CONCAT(b_no, '_', n.n) AS sid,
        1 + FLOOR(POW((CRC32(CONCAT('ec', b_no, '_', n.n)) % 100000) / 100000.0, 2.0) * p_ncust)
            AS customer_id,
        /* session starts are spaced by whole hours -> always > 30 min apart */
        TIMESTAMP('2026-01-01')
          + INTERVAL (CRC32(CONCAT('es', b_no, '_', n.n)) % 4400) HOUR
          + INTERVAL (CRC32(CONCAT('em', b_no, '_', n.n)) % 60) MINUTE
            AS session_start,
        2 + (CRC32(CONCAT('en', b_no, '_', n.n)) % 11) AS n_events,
        2 + (CRC32(CONCAT('eg', b_no, '_', n.n)) % 7)  AS gap_min,
        ELT(1 + (CRC32(CONCAT('ed', b_no, '_', n.n)) % 3), 'Android','iOS','Desktop') AS device
      FROM nums n CROSS JOIN (SELECT b AS b_no) bb
      WHERE n.n < 3200
    ) s
    JOIN nums e ON e.n < s.n_events;
    SET b = b + 1;
  END WHILE;
END$$
DELIMITER ;

CALL build_events(@SCALE, @N_CUST);
DROP PROCEDURE build_events;

/* ==================================================================
   8. STG_CUSTOMER_RECORDS  — deliberately dirty
   ------------------------------------------------------------------
   Each customer gets 1 base record; ~35% also get 1-3 later "updates"
   from different source systems. Same customer_id, different
   record_id and updated_at. That is exactly what Deduplication
   (Pattern 9) is for.
   ================================================================== */

CREATE TABLE stg_customer_records (
  record_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id   INT UNSIGNED NOT NULL,
  phone         VARCHAR(15)  NOT NULL,
  email         VARCHAR(60)  NOT NULL,
  city          VARCHAR(40)  NOT NULL,
  source_system VARCHAR(12)  NOT NULL,
  updated_at    DATETIME     NOT NULL,
  INDEX ix_stg_cust (customer_id, updated_at)
) ENGINE=InnoDB;

INSERT INTO stg_customer_records
  (customer_id, phone, email, city, source_system, updated_at)
SELECT
  c.customer_id,
  CONCAT('9', LPAD((CRC32(CONCAT('ph', c.customer_id, '_', v.n)) % 1000000000), 9, '0')),
  CONCAT(LOWER(REPLACE(c.customer_name, ' ', '.')), c.customer_id, '@mail.com'),
  CASE WHEN v.n = 0 THEN c.city
       ELSE ELT(1 + (CRC32(CONCAT('ct', c.customer_id, '_', v.n)) % 4),
                c.city, 'Chennai', 'Bengaluru', 'Mumbai') END,
  ELT(1 + (CRC32(CONCAT('ss', c.customer_id, '_', v.n)) % 4),
      'POS','CRM','WEBFORM','CALLCTR'),
  TIMESTAMP('2026-01-01')
    + INTERVAL (CRC32(CONCAT('ua', c.customer_id, '_', v.n)) % 180) DAY
    + INTERVAL (v.n * 7 + (CRC32(CONCAT('uh', c.customer_id, '_', v.n)) % 24)) HOUR
FROM dim_customer c
JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) v
  ON v.n = 0
  OR (v.n <= (CRC32(CONCAT('dup', c.customer_id)) % 4)
      AND (CRC32(CONCAT('hasdup', c.customer_id)) % 100) < 35);

/* ---------- 9. RESTORE SAFE SESSION SETTINGS ---------- */
SET SESSION unique_checks = 1;
SET SESSION foreign_key_checks = 1;
