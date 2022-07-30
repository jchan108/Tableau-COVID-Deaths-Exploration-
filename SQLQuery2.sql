/*
Covid 19 Data Exploration 
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/


--Select the data that we will use
--shows Likelihood if dying if you contract COVID in U.S.
SELECT Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM CovidDeaths
WHERE location like 'United States'
AND continent is not null 
ORDER BY 1,2

--Looking at the total cases vs total deaths
--at the end of 2020, 352,093 total deaths in US
--  as of 2021 4-30, 32346971 infected, 576232 deaths, 1.78% chance of death.

--Look at the total cases vs the population
--shows what percent of the population got covid
SELECT Location, date, total_cases, total_deaths, (total_cases/population)*100 as InfectPercentage
FROM CovidDeaths
WHERE location like 'United States'
AND continent is not null 
ORDER BY 1,2

--Looking at countries with highest infection rate compared to population
SELECT Location, Population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM CovidDeaths
GROUP BY Location, Population
ORDER BY PercentPopulationInfected Desc

--Looking at countries with highest infection rate compared to population (for each day)
SELECT Location, Population, date, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM CovidDeaths
GROUP BY Location, Population, date
ORDER BY PercentPopulationInfected Desc


--Showing countries with the highest death count per population
SELECT Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
FROM CovidDeaths
Where continent is not null
GROUP BY Location
ORDER BY TotalDeathCount desc


-- Break down by continent, display total cases for each continent, and total death count of each continet
SELECT continent, MAX(total_cases) AS TotalCaseCount, MAX(cast(Total_deaths as int)) as TotalDeathCount
FROM CovidDeaths
WHERE continent is NOT null
GROUP BY continent
ORDER BY TOTALDEATHCOUNT desc

--Showing continents with the highest death count per population
--Global Numbers

Select date, SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(new_cases)*100 as DeathPercentage
--running below line will return single values
--Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
FROM CovidDeaths
WHERE continent is not null
GROUP BY date
ORDER by 1,2


/*
--practice example of below with partition only by location
--incorrect, produces the total vaccinated for each country
--must partition by Location AND date
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
--OVER (   
--       [ <PARTITION BY clause> ]      [ <ORDER BY clause> ]       [ <ROW or RANGE clause> ]   )  
--partition on location so it runs only through each country
SUM(cast(vac.new_vaccinations as int)) OVER (Partition by dea.location) as RollingPeopleVaccinated
FROM CovidDeaths dea
INNER JOIN CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent is not null
ORDER BY 2,3
*/

--Looking at total population vs vaccinations
--shows percent of population that has received at least one Covid Vaccine
--goal is to do a rolling count of vaccinations for each country
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
--we want to later figure out what percent of people in each country are vaccinated at the end of the day
SUM(cast(vac.new_vaccinations as int)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingPeopleVaccinated
--,(RollingPeopleVaccinated/population)*100 this will produce an error, we cannot use a column we just created as a basis for another column
--options to fix: use CTE
FROM CovidDeaths dea
INNER JOIN CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent is not null
ORDER BY 2,3
--We end up with a table of Location, Date, Population, number of new vaccinations per day, and the total count of people vaccinated at the end of each day.

/*
SELECT * FROM PortfolioProject..CovidDeaths dea
INNER JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent is not null
*/


--use CTE to perform calculation on the partition in the above query (Common Table Expression)
--CTE is result of a query which exists temporarily and for use only within context of a larger query
--initiate a CTE using WITH name(new columns) AS () 
-- if # of tables in CTE is different from # of columns that you selected, it will give an error
--CTE only exists during the query run
--must run the select from popvsvac after the with()
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(cast(vac.new_vaccinations as int)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated

FROM CovidDeaths dea
JOIN CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent is not null
--ORDER BY 2,3 
--cannot use order by clause in views, common table expressions 
)
SELECT *, (RollingPeopleVaccinated/Population)*100 AS PercentCountryVaccinated
FROM PopvsVac


--query that we were looking at is in here, but now we can use it to perform further calculations


--TEMP TABLE
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

INSERT into #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
FROM CovidDeaths dea
-- multiple joins required, compound primary key.
JOIN CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
--WHERE dea.continent is not null
--ORDER BY 2,3 

SELECT *, (RollingPeopleVaccinated/Population)*100
FROM #PercentPopulationVaccinated

-- DROP VIEW IF EXISTS PercentPopulationVaccinatedView
Create View PercentPopulationVaccinatedView as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From CovidDeaths dea
Join CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 

SELECT * FROM PercentPopulationVaccinated

-- Check the View
-- SELECT * FROM PercentPopulationVaccinatedView















