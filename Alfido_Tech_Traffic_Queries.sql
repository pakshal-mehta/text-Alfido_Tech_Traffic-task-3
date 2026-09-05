-- =====================================================================
-- Alfido Tech - Website Traffic Analysis Queries
-- Assumes a table named "traffic" already exists with these columns:
--   event   (pageview | preview | click)
--   date
--   country, city, artist, album, track, isrc, linkid
-- Portable ANSI SQL - verified error-free (tested on SQLite; standard
-- CASE/GROUP BY/LIMIT syntax works unchanged on PostgreSQL and MySQL;
-- SQL Server users should replace "LIMIT n" with "TOP n" in the SELECT).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Core metrics summary
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                              AS total_events,
    SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END)   AS pageviews,
    SUM(CASE WHEN event = 'click'    THEN 1 ELSE 0 END)   AS clicks,
    SUM(CASE WHEN event = 'preview'  THEN 1 ELSE 0 END)   AS previews,
    COUNT(DISTINCT linkid)                                AS unique_landing_pages,
    COUNT(DISTINCT country)                                AS unique_countries,
    COUNT(DISTINCT artist)                                 AS unique_artists,
    ROUND(100.0 * SUM(CASE WHEN event = 'click'   THEN 1 ELSE 0 END)
                / NULLIF(SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END), 0), 2) AS ctr_pct,
    ROUND(100.0 * SUM(CASE WHEN event = 'preview' THEN 1 ELSE 0 END)
                / NULLIF(SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END), 0), 2) AS preview_rate_pct
FROM traffic;


-- ---------------------------------------------------------------------
-- 2. Bounce-rate proxy: % of landing pages with pageviews but
--    zero downstream engagement (no click, no preview)
-- ---------------------------------------------------------------------
WITH link_stats AS (
    SELECT
        linkid,
        SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END) AS pageviews,
        SUM(CASE WHEN event = 'preview'  THEN 1 ELSE 0 END) AS previews,
        SUM(CASE WHEN event = 'click'    THEN 1 ELSE 0 END) AS clicks
    FROM traffic
    GROUP BY linkid
)
SELECT
    ROUND(100.0 * SUM(CASE WHEN pageviews > 0 AND clicks = 0 AND previews = 0 THEN 1 ELSE 0 END)
                / NULLIF(SUM(CASE WHEN pageviews > 0 THEN 1 ELSE 0 END), 0), 2) AS bounce_rate_proxy_pct
FROM link_stats;


-- ---------------------------------------------------------------------
-- 3. Top 10 entry (landing) pages by pageviews
-- ---------------------------------------------------------------------
WITH link_stats AS (
    SELECT
        linkid,
        MAX(artist) AS artist,
        MAX(track)  AS track,
        SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END) AS pageviews,
        SUM(CASE WHEN event = 'preview'  THEN 1 ELSE 0 END) AS previews,
        SUM(CASE WHEN event = 'click'    THEN 1 ELSE 0 END) AS clicks
    FROM traffic
    GROUP BY linkid
)
SELECT
    linkid, artist, track, pageviews, previews, clicks,
    ROUND(100.0 * clicks / NULLIF(pageviews, 0), 2) AS ctr_pct
FROM link_stats
ORDER BY pageviews DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 4. Top 10 exit / drop-off pages: pageviews >= 50, lowest CTR
-- ---------------------------------------------------------------------
WITH link_stats AS (
    SELECT
        linkid,
        MAX(artist) AS artist,
        MAX(track)  AS track,
        SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END) AS pageviews,
        SUM(CASE WHEN event = 'preview'  THEN 1 ELSE 0 END) AS previews,
        SUM(CASE WHEN event = 'click'    THEN 1 ELSE 0 END) AS clicks
    FROM traffic
    GROUP BY linkid
)
SELECT
    linkid, artist, track, pageviews, previews, clicks,
    ROUND(100.0 * clicks / NULLIF(pageviews, 0), 2) AS ctr_pct
FROM link_stats
WHERE pageviews >= 50
ORDER BY ctr_pct ASC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 5. Daily event trend (for the line chart)
-- ---------------------------------------------------------------------
SELECT
    date,
    SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END) AS pageviews,
    SUM(CASE WHEN event = 'preview'  THEN 1 ELSE 0 END) AS previews,
    SUM(CASE WHEN event = 'click'    THEN 1 ELSE 0 END) AS clicks
FROM traffic
GROUP BY date
ORDER BY date;


-- ---------------------------------------------------------------------
-- 6. Event type distribution (for the pie chart)
-- ---------------------------------------------------------------------
SELECT
    event,
    COUNT(*) AS event_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM traffic), 2) AS pct_of_total
FROM traffic
GROUP BY event
ORDER BY event_count DESC;


-- ---------------------------------------------------------------------
-- 7. Top 15 countries by traffic volume (referral-source proxy;
--    the source data has no referrer/UTM column)
-- ---------------------------------------------------------------------
SELECT
    country,
    COUNT(*) AS total_events,
    SUM(CASE WHEN event = 'pageview' THEN 1 ELSE 0 END) AS pageviews
FROM traffic
GROUP BY country
ORDER BY total_events DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- 8. Aggregate user-journey funnel: Pageview -> Preview -> Click
-- ---------------------------------------------------------------------
SELECT 'Pageview' AS stage, 1 AS stage_order, COUNT(*) AS event_count FROM traffic WHERE event = 'pageview'
UNION ALL
SELECT 'Preview',  2, COUNT(*) FROM traffic WHERE event = 'preview'
UNION ALL
SELECT 'Click',    3, COUNT(*) FROM traffic WHERE event = 'click'
ORDER BY stage_order;


-- ---------------------------------------------------------------------
-- 9. Top 10 tracks by pageviews
-- ---------------------------------------------------------------------
SELECT
    artist, track, COUNT(*) AS pageviews
FROM traffic
WHERE event = 'pageview'
GROUP BY artist, track
ORDER BY pageviews DESC
LIMIT 10;
