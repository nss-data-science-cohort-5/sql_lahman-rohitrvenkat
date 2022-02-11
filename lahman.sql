-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)

-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
SELECT 
	namefirst, 
	namelast,
	SUM(salary::numeric::money) AS total_salary
FROM people
INNER JOIN salaries
USING (playerid)
WHERE playerid IN (
	SELECT 
		playerid
	FROM collegeplaying
	WHERE schoolid = 'vandy' )
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;


-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
SELECT 
	CASE
		WHEN pos = 'OF' THEN 'Outfield'
		WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
		WHEN pos IN ('P', 'C') THEN 'Battery'
	END AS position,
	SUM(po) AS putouts
FROM fielding
WHERE yearid = 2016
GROUP BY position
ORDER BY putouts DESC;


-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
WITH bins AS (
	SELECT 
		generate_series(1920, 2010, 10) AS lower,
		generate_series(1929, 2019, 10) AS upper )
SELECT 
	lower AS decade,
	ROUND(SUM(so) * 2.0 / SUM(g), 2) AS strikeouts_per_game,
	ROUND(SUM(hr) * 2.0 / SUM(g), 2) AS homeruns_per_game
FROM bins
LEFT JOIN teams
	ON yearid >= lower
	AND yearid < upper
GROUP BY lower, upper
ORDER BY lower DESC;


WITH so_hr_decades AS (
	SELECT 
		yearid,
		teamid,
		g,
		FLOOR(yearid/10)*10 AS decade,
		so,
		hr
	FROM teams
)
SELECT
	decade,
	ROUND(SUM(so)*2.0/(SUM(g)), 2) AS so_per_game,
	ROUND(SUM(hr)*2.0/(SUM(g)), 2) AS hr_per_game
FROM so_hr_decades
GROUP BY decade
ORDER BY decade;


-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.
SELECT 
	namefirst || ' ' || namelast AS full_name,
	sb AS stolen_bases,
	sb + cs AS stealing_attempts,
	ROUND(sb::numeric / (sb + cs), 2) AS stealing_success_pct
FROM batting
INNER JOIN people
USING(playerid)
WHERE yearid = 2016 
	AND (sb + cs) >= 20
ORDER BY stealing_success_pct DESC;


-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?
SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'N'
ORDER BY w DESC;


SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'Y'
ORDER BY w;


SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND yearid != 1981
	AND wswin = 'Y'
ORDER BY w;


SELECT 
	SUM(CASE WHEN wswin = 'Y' THEN 1 END) AS ws_wins,
	ROUND(SUM(CASE WHEN wswin = 'Y' THEN 1 END)::numeric / COUNT(*), 3) AS ws_win_pct
FROM teams
INNER JOIN (
	SELECT yearid, MAX(w) AS w
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
	AND wswin IS NOT NULL
	GROUP BY yearid ) AS most_wins_by_year
USING(yearid, w);


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.
SELECT
	namefirst || ' ' || namelast AS full_name,
	yearid,
	teamid,
	lgid
FROM awardsmanagers
INNER JOIN (
	SELECT 
		playerid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
	GROUP BY playerid
	HAVING COUNT(DISTINCT lgid) = 2 ) AS both_leagues
USING(playerid)
INNER JOIN people
USING(playerid)
INNER JOIN managers
USING(playerid, yearid, lgid);


-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.
SELECT
	playerid,
	namefirst || ' ' || namelast AS full_name,
	SUM(salary)::numeric::money AS salary,
	SUM(so) AS strikeouts,
	SUM(salary)::numeric::money / SUM(so) AS dollars_per_strikeout
FROM pitching
FULL JOIN salaries
USING(playerid, yearid, teamid)
INNER JOIN people
USING(playerid) 
WHERE yearid = 2016
GROUP BY full_name, playerid
HAVING SUM(gs) >= 10 
	AND SUM(salary) IS NOT NULL
ORDER BY dollars_per_strikeout DESC;


WITH salary AS (
	SELECT
		playerid,
		SUM(salary) AS salary
	FROM salaries
	WHERE yearid = 2016
	GROUP BY 1
),
strikeouts AS (
	SELECT
		playerid,
		SUM(so) AS strikeouts,
		SUM(gs) AS games_started
	FROM pitching
	WHERE yearid = 2016
	GROUP BY 1
)
SELECT
	p.playerid,
	p.namefirst || ' ' || p.namelast AS full_name,
	s.salary,
	so.strikeouts,
	ROUND((s.salary / so.strikeouts)::numeric, 2)::money AS salary_per_strikeout
FROM people p
JOIN salary s ON p.playerid = s.playerid
JOIN strikeouts so ON s.playerid = so.playerid
WHERE so.games_started >= 10
GROUP BY 1,2,3,4
ORDER BY 5 DESC


-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.
SELECT 
	namefirst || ' ' || namelast AS full_name,
	SUM(h) AS career_hits,
	inducted
FROM batting
INNER JOIN people
USING(playerid)
LEFT JOIN (
	SELECT
		playerid,
		CASE 
			WHEN inducted = 'Y' THEN yearid
			ELSE NULL
		END AS inducted
	FROM halloffame
	WHERE inducted = 'Y' ) AS hall_of_fame
USING(playerid)
GROUP BY full_name, inducted
HAVING SUM(h) >= 3000
ORDER BY career_hits DESC;


-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.
SELECT
	namefirst || ' ' || namelast AS full_name,
	string_agg(teamid, ', ') AS teams,
	string_agg(hits::text, ', ') AS hits
FROM (
	SELECT 
		playerid, 
		teamid, 
		SUM(h) AS hits
	FROM batting
	GROUP BY playerid, teamid
	HAVING SUM(h) >= 1000 ) AS hits_by_team
INNER JOIN people
USING(playerid)
GROUP BY full_name
HAVING COUNT(DISTINCT teamid) > 1;


-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.



-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.



-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?



--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.



-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?


