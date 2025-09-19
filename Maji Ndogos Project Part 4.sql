-- Transforming Maji Ndogo Water Data into Actionable Knowledge
-- Goal:
-- We want to combine all relevant data into a single, clean dataset that decision-makers can use to:
-- Understand water source types and their locations.
-- Track how many people are served by each source.
-- See queue times for each visit.
-- Check well water pollution levels.
-- Identify towns or provinces with the greatest needs for repair or intervention.
-- Step 1: Identify the Questions to Answer

-- From the president’s email, we focus on these questions:
-- Are certain provinces or towns more abundant in specific water source types?
-- Are there towns where broken taps (tap_in_home_broken) are especially common?

-- Step 2: Combine Data from Multiple Tables

CREATE VIEW combined_analysis_table AS
SELECT
    water_source.type_of_water_source AS source_type,
    location.town_name,
    location.province_name,
    location.location_type,
    water_source.number_of_people_served AS people_served,
    visits.time_in_queue,
    well_pollution.results
FROM visits
LEFT JOIN well_pollution
    ON well_pollution.source_id = visits.source_id
INNER JOIN location
    ON location.location_id = visits.location_id
INNER JOIN water_source
    ON water_source.source_id = visits.source_id
WHERE visits.visit_count = 1;
-- The above code gives an out come of a single, clean table (combined_analysis_table) that consolidates all relevant data for analysis.


-- Provincial Water Source Analysis
-- We Identify which provinces have the greatest needs based on water source type and population served.

-- Step 1: Calculate total population served per province
WITH province_totals AS (
    SELECT
        province_name,
        SUM(people_served) AS total_ppl_serv
    FROM combined_analysis_table
    GROUP BY province_name
),

-- Step 2: Aggregate water source types per province
-- Each column represents a type of water source.
-- Values are percentages of total population in that province.
province_water_distribution AS (
    SELECT
        ct.province_name,
        ROUND((SUM(CASE WHEN source_type = 'river' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
        ROUND((SUM(CASE WHEN source_type = 'shared_tap' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
        ROUND((SUM(CASE WHEN source_type = 'tap_in_home' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
        ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
        ROUND((SUM(CASE WHEN source_type = 'well' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
    FROM combined_analysis_table ct
    JOIN province_totals pt
        ON ct.province_name = pt.province_name
    GROUP BY ct.province_name
)

-- Step 3: Retrieve final results, ordered by descending population percentage of broken taps
SELECT *
FROM province_water_distribution
ORDER BY tap_in_home_broken DESC;

/*
Interpretation of water source distribution by province:

Sokoto:
- 21% use rivers
- 38% use shared taps (most common)
- 16% have functioning taps at home
- 10% have broken taps at home
- 15% use wells
=> Shared taps dominate; broken taps indicate maintenance needs.

Kilimani:
- 8% use rivers
- 47% use shared taps
- 13% have working taps at home
- 12% have broken taps at home
- 20% use wells
=> High dependence on shared taps and wells; some broken taps.

Hawassa:
- 4% use rivers
- 43% use shared taps
- 15% have working taps at home
- 15% have broken taps at home
- 24% use wells
=> Largest reliance on wells; broken taps also high, signaling repair needs.

Amanzi:
- 3% use rivers
- 38% use shared taps
- 28% have functioning taps at home
- 24% have broken taps at home
- 7% use wells
=> Many taps at home, but almost as many are broken; wells less used.

Akatsi:
- 5% use rivers
- 49% use shared taps (highest)
- 14% have working taps at home
- 10% have broken taps at home
- 23% use wells
=> Heavy reliance on shared taps; wells also significant; fewer broken taps.

Overall Patterns:
1. Shared taps are the most common source in all provinces.
2. Broken taps at home are an issue, especially in Amanzi and Hawassa.
3. Wells are important in Hawassa and Akatsi.
4. These insights help target repair teams to areas with high need.
*/

-- Town-Level Aggregation of People Served
-- We want to calculate total people served per town, which will allow us to later calculate percentages of each water source type.
 

-- Step 1: Aggregate total people served per town

WITH town_totals AS (
    SELECT
        province_name,
        town_name,
        SUM(people_served) AS total_ppl_serv
    FROM combined_analysis_table
    GROUP BY province_name, town_name
    ORDER BY  SUM(people_served) DESC 
)
SELECT * FROM town_totals;

/* The Funding are as follows: 
Akatsi, Rural — 4,602,096
Kilimani, Rural — 4,054,284
Sokoto, Rural — 3,989,718
Hawassa, Rural — 2,859,154
Amanzi, Rural — 2,135,046
 So the Key Takeaway 
 Rural areas dominate the top totals. Most large populations are in “Rural” town entries.
Akatsi, Kilimani and Sokoto provinces contain the largest town populations.
These totals show where repairs will have the largest reach — fixing a problem in the big towns affects far more people.
*/

-- Step 2: Calculate Percentages per Water Source Type per Town
-- Next, we calculate the percentage of people served by each type of water source within each town.


WITH town_totals AS (
    SELECT
        province_name,
        town_name,
        SUM(people_served) AS total_ppl_serv
    FROM combined_analysis_table
    GROUP BY province_name, town_name
)
SELECT
    cat.province_name,
    cat.town_name,
    ROUND((SUM(CASE WHEN source_type = 'river' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river_pct,
    ROUND((SUM(CASE WHEN source_type = 'shared_tap' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap_pct,
    ROUND((SUM(CASE WHEN source_type = 'tap_in_home' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_pct,
    ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken_pct,
    ROUND((SUM(CASE WHEN source_type = 'well' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well_pct
FROM combined_analysis_table cat
JOIN town_totals tt 
    ON cat.province_name = tt.province_name AND cat.town_name = tt.town_name
GROUP BY cat.province_name, cat.town_name, tt.total_ppl_serv
ORDER BY province_name, town_name DESC;

/*Town-level source-type percentages
We calculated, per town, the percentage of people served by each source type. Sample results and what they mean:
Akatsi, Rural — river 6%, shared_tap 59%, tap_in_home 9%, tap_in_home_broken 5%, well 22%
→ Shared taps are dominant; wells also matter.
Akatsi, Lusaka — river 2%, shared_tap 17%, tap_in_home 28%, tap_in_home_broken 28%, well 26%
→ Many home taps installed, but roughly as many are broken as working — infrastructure exists but is failing.
Akatsi, Kintampo / Harare — similar pattern: strong home-tap presence (around 28–31%) and high broken percentages (26–27%) plus sizable well usage (26–27%).
→ Installed systems that are not reliably working.
Amanzi, Rural — river 3%, shared_tap 27%, tap_in_home 30%, tap_in_home_broken 30%, well 10%
→ Half of home taps in the rural area are broken — urgent repairs needed.
Amanzi, Dahabu — river 3%, shared_tap 37%, tap_in_home 55%, tap_in_home_broken 1%, well 4%
→ Dahabu is an outlier: many home taps and almost none broken — infrastructure here works well.
Amanzi, Pwani / Bello / Asmara — large shared_tap percentages (49–53%) with moderate home-tap shares.
→ Heavy reliance on shared taps in those towns.
General patterns 
Shared taps are the most common source type in many towns.
Several towns have substantial home-tap infrastructure but also high broken-tap percentages — that means infrastructure exists but needs repair.
Dahabu is a positive outlier (working home taps).
Rivers are generally a small share at town level in this sample.
Action implications (Step 2)
Towns with many broken home taps but high tap_in_home share should be prioritized for repairs (fix existing infrastructure rather than installing new taps).
Towns dominated by shared taps are candidates for tactical short-term support (tankers) and medium-term expansion (additional taps).
*/




-- Step 3: Calculate Percentage of Broken Taps per Town
-- Now we identify towns where installed taps exist but are not functional, which helps prioritize repairs.

-- Step 3: Calculate % of broken taps
SELECT
    province_name,
    town_name,
    ROUND(tap_in_home_broken_pct / (tap_in_home_broken_pct + tap_in_home_pct) * 100, 0) AS pct_broken_taps
FROM (
    -- Use the town-level percentages calculated in Step 2
    WITH town_totals AS (
        SELECT
            province_name,
            town_name,
            SUM(people_served) AS total_ppl_serv
        FROM combined_analysis_table
        GROUP BY province_name, town_name
    )
    SELECT
        cat.province_name,
        cat.town_name,
        SUM(CASE WHEN source_type = 'tap_in_home' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv AS tap_in_home_pct,
        SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv AS tap_in_home_broken_pct
    FROM combined_analysis_table cat
    JOIN town_totals tt 
        ON cat.province_name = tt.province_name AND cat.town_name = tt.town_name
    GROUP BY cat.province_name, cat.town_name, tt.total_ppl_serv
) AS town_data
ORDER BY pct_broken_taps DESC;

/* The Findings are as follows: Percentage of broken taps (priority list)
computed the percent of taps that are installed but broken in each town. Top results:
Amanzi, Amina — 95% broken
Kilimani, Zuri — 65% broken
Hawassa, Amina — 56% broken
Hawassa, Djenne — 55% broken
Amanzi, Bello — 53% broken
Hawassa, Yaounde — 52% broken
Amanzi, Pwani — 52% broken etc ...

Key takeaways 
Amanzi, Amina (95%) is an extreme hotspot — virtually all installed home taps there are non-functional. That town should be top repair priority.
Many towns have very high broken-tap ratios (40–65%), meaning installed infrastructure is widespread but failing.
Some towns (e.g., Dahabu) have functioning infrastructure and can serve as models for what works.
Action Plan
Build a prioritized repair list: start with towns that combine high pct_broken_taps and large total population (use Step 1 totals to rank impact).
For towns like Amanzi Amina, dispatch engineering teams immediately and consider temporary water delivery while repairs are done.
Record each planned repair in Project_progress (source_id, address, improvement, status, comments).
*/

-- Final Project_progress Query
-- Here’s the full query with all improvements:
SELECT
    location.address,
    location.town_name,
    location.province_name,
    water_source.source_id,
    water_source.type_of_water_source,
    well_pollution.results,
    visits.time_in_queue,
    visits.visit_count,
    CASE
        WHEN water_source.type_of_water_source = 'well'
             AND well_pollution.results = 'Contaminated: Chemical'
        THEN 'Install RO filter'

        WHEN water_source.type_of_water_source = 'well'
             AND well_pollution.results = 'Contaminated: Biological'
        THEN 'Install UV and RO filter'

        WHEN water_source.type_of_water_source = 'river'
        THEN 'Drill well'

        WHEN water_source.type_of_water_source = 'shared_tap'
             AND visits.time_in_queue >= 30
        THEN CONCAT('Install ', FLOOR(visits.time_in_queue / 30), ' taps nearby')

        WHEN water_source.type_of_water_source = 'tap_in_home_broken'
        THEN 'Diagnose local infrastructure'

        ELSE NULL
    END AS Improvement
FROM
    water_source
LEFT JOIN
    well_pollution 
    ON water_source.source_id = well_pollution.source_id
INNER JOIN
    visits 
    ON water_source.source_id = visits.source_id
INNER JOIN
    location 
    ON location.location_id = visits.location_id
WHERE
    visits.visit_count = 1
    AND (
        (water_source.type_of_water_source = 'well' AND well_pollution.results != 'Clean')
        OR water_source.type_of_water_source = 'river'
        OR water_source.type_of_water_source = 'tap_in_home_broken'
        OR (water_source.type_of_water_source = 'shared_tap' AND visits.time_in_queue >= 30)
    );
    
    


