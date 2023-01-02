-- Check all the rows were imported from CSV files
SELECT COUNT(*) FROM daily_activity;
SELECT COUNT(*) FROM hourly_steps;
SELECT COUNT(*) FROM hourly_calories;
SELECT COUNT(*) FROM daily_sleep;
SELECT COUNT(*) FROM weight_log;

-- Check the number of unique ids each table has
SELECT COUNT(DISTINCT id) FROM daily_activity;
SELECT COUNT(DISTINCT id) FROM hourly_steps;
SELECT COUNT(DISTINCT id) FROM hourly_calories;
SELECT COUNT(DISTINCT id) FROM daily_sleep;
SELECT COUNT(DISTINCT id) FROM weight_log;

-- Compare the unique id in each table to check if all tables contain the same ids
SELECT 
	DISTINCT da.id AS daily_activity_ids, 
	ds.id AS daily_sleep_ids, 
	hc.id AS hourly_calories_ids,
	hs.id AS hourly_steps_ids,
	wl.id AS weight_log_ids
FROM daily_activity da 
LEFT JOIN (SELECT DISTINCT id FROM daily_sleep) ds 
	ON ds.id = da.id 
LEFT JOIN (SELECT DISTINCT id FROM hourly_calories) hc 
	ON hc.id = da.id
LEFT JOIN (SELECT DISTINCT id  FROM hourly_steps) hs 
	ON hs.id = da.id
LEFT JOIN (SELECT DISTINCT id FROM weight_log) wl 
	ON wl.id = da.id;
    
-- Create new hourly view where the datetime component is split into date and time columns

CREATE VIEW hourly_calories_formatted
AS (SELECT 
		id,
        CAST(ActivityHour as date) AS date, 
        CAST(ActivityHour as time) AS time, 
        calories 
	FROM hourly_calories);


CREATE VIEW hourly_steps_formatted
AS (SELECT 
		id,
        CAST(ActivityHour as date) AS date, 
        CAST(ActivityHour as time) AS time, 
        StepTotal 
	FROM hourly_steps);


-- Number of date recorded for each participant. Decided to remove participant 4057192912 because they only have 4 days of data collection
SELECT * FROM hourly_calories_formatted ;
SELECT * FROM hourly_steps_formatted ;

SELECT id, COUNT(DISTINCT date) FROM hourly_calories_formatted GROUP BY (id );
SELECT id, COUNT(DISTINCT date) FROM hourly_steps_formatted GROUP BY (id );

SELECT id, hc.num_days_calories_collected, hs.num_days_steps_collected, ds.num_days_sleep_collected, da.num_days_activity_collected
FROM (
	SELECT id, COUNT(DISTINCT date) AS num_days_calories_collected 
    FROM hourly_calories_formatted 
    GROUP BY (id)
    ) hc
LEFT JOIN (
	SELECT id, COUNT(DISTINCT date) AS num_days_steps_collected 
    FROM hourly_steps_formatted 
    GROUP BY (id)
) hs USING(id)
LEFT JOIN (
	SELECT id, COUNT(DISTINCT sleepday) AS num_days_sleep_collected 
    FROM daily_sleep
    GROUP BY (id)
) ds USING(id)
LEFT JOIN (
	SELECT id, COUNT(DISTINCT activitydate) AS num_days_activity_collected 
    FROM daily_activity
    GROUP BY (id)
) da USING(id)
;

-- Remove day 2016-05-12 because most participants dont have full 24 hours of data for that day
SELECT id, date, hc.num_hours_calories_collected, hs.num_hours_steps_collected
FROM (
	SELECT id, date , COUNT(DISTINCT time) AS num_hours_calories_collected
FROM hourly_calories_formatted 
GROUP BY id, date
HAVING COUNT(DISTINCT time) < 24
    ) hc
JOIN (
	SELECT id, date , COUNT(DISTINCT time) AS num_hours_steps_collected
FROM hourly_steps_formatted 
GROUP BY id, date
HAVING COUNT(DISTINCT time) < 24
) hs USING(id , date);

    
SELECT CAST(ActivityHour as date) , COUNT(DISTINCT id) FROM hourly_calories GROUP BY (CAST(ActivityHour as date) );
SELECT id, COUNT(DISTINCT CAST(ActivityHour as date) ) FROM hourly_calories GROUP BY(id);

-- Combine calories and steps to one table create averages for hours across all days
-- REMOVE 2016-05-12 AND 4057192912 
CREATE TABLE hourly_avg_steps_calories AS (
SELECT hc.id, hc.time, hc.avg_calories, hs.avg_steps 
FROM 
	(SELECT id, time, AVG(calories) AS avg_calories
	FROM
		hourly_calories_formatted 
	WHERE id <> "4057192912" AND date <> "2016-05-12"
	GROUP BY id, time
    ) hc
LEFT JOIN 
	(
    SELECT id, time, AVG(steptotal) AS avg_steps
	FROM
		hourly_steps_formatted 
	WHERE id <> "4057192912" AND date <> "2016-05-12"
	GROUP BY id, time) hs
USING (id, time)
UNION
SELECT hc.id, hc.time, hc.avg_calories, hs.avg_steps 
FROM 
	(SELECT id, time, AVG(calories) AS avg_calories
	FROM
		hourly_calories_formatted 
	WHERE id <> "4057192912" AND date <> "2016-05-12"
	GROUP BY id, time
    ) hc
RIGHT JOIN 
	(
    SELECT id, time, AVG(steptotal) AS avg_steps
	FROM
		hourly_steps_formatted 
	WHERE id <> "4057192912" AND date <> "2016-05-12"
	GROUP BY id, time) hs
USING (id, time)
);


-- Combine daily activity and daily sleep, filter daily acitvity to categories
-- REMOVE 2016-05-12 AND 4057192912 

CREATE VIEW daily_activity_formatted AS (
SELECT 
	id, 
	CAST(activityDate as date) AS date, 
	totalSteps AS total_steps, 
    calories AS total_calories,
	veryactiveminutes AS very_active_mins, 
	fairlyactiveminutes AS fairly_active_mins,
    lightlyactiveminutes AS lightly_active_mins,
    sedentaryminutes AS sedentary_mins
FROM daily_activity
WHERE id <> "4057192912" AND CAST(activityDate as date) <> "2016-05-12")
;

CREATE VIEW daily_sleep_formatted AS (
SELECT 
	id, 
	CAST(sleepday as date) AS date, 
	totalminutesasleep AS total_mins_asleep, 
    totaltimeinbed AS total_mins_in_bed
FROM daily_sleep
WHERE id <> "4057192912" AND CAST(sleepday as date) <> "2016-05-12")
;

CREATE TABLE daily_activity_and_sleep AS (
SELECT 
	daf.id, 
    daf.date, 
    daf.total_steps, 
    daf.total_calories, 
    daf.very_active_mins, 
    daf.fairly_active_mins, 
    daf.lightly_active_mins, 
    daf.sedentary_mins,
    dsf.total_mins_asleep,
    dsf.total_mins_in_bed
FROM daily_activity_formatted daf
LEFT JOIN
daily_sleep_formatted dsf
USING (id)
);




SELECT activeness_level, COUNT(*) FROM (
SELECT 
	id, 
    AVG(total_steps) AS avg_total_steps, 
    AVG(total_calories) AS avg_total_calories,
	AVG(very_active_mins) AS avg_very_active_mins, 
	AVG(fairly_active_mins) AS avg_fairly_active_mins,
    AVG(lightly_active_mins) AS avg_lighly_active_mins,
    AVG(sedentary_mins) AS avg_sedentary_mins,
    AVG(total_mins_asleep) AS avg_total_mins_asleep,
    AVG(total_mins_in_bed) AS total_mins_in_bed,
	CASE
    WHEN AVG(very_active_mins) > 30 THEN 'VERY_ACTIVE'
    WHEN AVG(fairly_active_mins) >20 OR AVG(lightly_active_mins) >120 THEN 'ACTIVE'
    ELSE 'NOT_ACTIVE'
    END AS activeness_level
FROM daily_activity_and_sleep
GROUP BY id) ddd
GROUP BY activeness_level;


CREATE TABLE participant_avg_daily_activity_and_sleep AS (
SELECT 
	id, 
    AVG(total_steps) AS avg_total_steps, 
    AVG(total_calories) AS avg_total_calories,
	AVG(very_active_mins) AS avg_very_active_mins, 
	AVG(fairly_active_mins) AS avg_fairly_active_mins,
    AVG(lightly_active_mins) AS avg_lighly_active_mins,
    AVG(sedentary_mins) AS avg_sedentary_mins,
    AVG(total_mins_asleep) AS avg_total_mins_asleep,
    AVG(total_mins_in_bed) AS total_mins_in_bed,
	CASE
    WHEN AVG(very_active_mins) > 30 THEN 'VERY_ACTIVE'
    WHEN AVG(fairly_active_mins) >20 OR AVG(lightly_active_mins) >120 THEN 'ACTIVE'
    ELSE 'NOT_ACTIVE'
    END AS activeness_level
FROM daily_activity_and_sleep
GROUP BY id
);


CREATE TABLE daily_avg_activity_and_sleep AS (
SELECT 
	date, 
    AVG(total_steps) AS avg_total_steps, 
    AVG(total_calories) AS avg_total_calories,
	AVG(very_active_mins) AS avg_very_active_mins, 
	AVG(fairly_active_mins) AS avg_fairly_active_mins,
    AVG(lightly_active_mins) AS avg_lighly_active_mins,
    AVG(sedentary_mins) AS avg_sedentary_mins,
    AVG(total_mins_asleep) AS avg_total_mins_asleep,
    AVG(total_mins_in_bed) AS total_mins_in_bed
FROM daily_activity_and_sleep
GROUP BY date
);



-- Filter weight loss to remove some collumns
CREATE VIEW weight_log_formatted AS(
SELECT 
	id, 
    CAST(date as date) AS date, 
    weightKg as weight_kg,
    BMI as bmi
FROM 
weight_log
WHERE id <> "4057192912")
;

CREATE TABLE weight AS(
SELECT 
	id, 
    CAST(date as date) AS date, 
    weightKg as weight_kg,
    BMI as bmi
FROM 
weight_log
WHERE id <> "4057192912")
;

