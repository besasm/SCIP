﻿CREATE PROCEDURE [dbo].[SP_FILL_ACTIVITIES]
AS
BEGIN
  SET NOCOUNT ON

  EXEC SP_STATUS_MESSAGE 'Begin SP_FILL_ACTIVITIES'
  TRUNCATE TABLE ACTIVITIES

  TRUNCATE TABLE CONTROLLING_DRIVER_FREQUENCIES
  INSERT INTO CONTROLLING_DRIVER_FREQUENCIES
    SELECT compkey, [Inspection] AS inspection_frequency_years, [Cleaning] AS cleaning_frequency_years, [Root Management] AS root_frequency_years
    FROM 
    (SELECT compkey, activity_type, frequency_years FROM VW_CONTROLLING_DRIVERS) PS
    PIVOT (AVG(frequency_years) FOR activity_type IN ([Inspection], [Cleaning], [Root Management])) AS PVT

  DECLARE @MaxYears DECIMAL(5,2)
  SET @MaxYears = 24

  DECLARE @statusMessage VARCHAR(200)
  SET @statusMessage = 'Processing ' + CONVERT(VARCHAR(10), @MaxYears) + ' years'
  EXEC SP_STATUS_MESSAGE @statusMessage

  ---- Paging algorithm
  --DECLARE @first_id INT, @startRow INT
  --CREATE TABLE #pageOfDrivers
  --(
  --  driver_id INT,
  --  driver_type_id INT,
  --  compkey INT,
  --  override_cost_per_ft MONEY,
  --  override_frequency_years FLOAT,
  --  alternative_id INT,
  --  updated_by VARCHAR(20),
  --  update_time DATETIME
  --)
  
  --SET ROWCOUNT @startRowIndex
  --SELECT @first_id = driver_id FROM DRIVERS ORDER BY driver_id 
  --SET ROWCOUNT @maximumRows

  --SELECT A.*
  --INTO #pageOfDrivers
  --FROM DRIVERS A
  --WHERE driver_id >= @first_id
  --ORDER BY A.driver_id
  --SET ROWCOUNT 0
  ----

  DECLARE @frequenciesTable TABLE
  (
    frequency_years DECIMAL(5,2),
    record_count INT
  )

  INSERT INTO @frequenciesTable
    SELECT frequency_years, COUNT(*)
    FROM VW_CONTROLLING_DRIVERS
    GROUP BY frequency_years

  DECLARE @InsertActivities TABLE
  (
	  COMPKEY int,
	  last_activity_date datetime,
	  next_activity_date datetime,
	  cost money,
	  reason nvarchar(20),
	  activity_type_id int, 
	  alternative_id int
  )

  DECLARE @CurrentDate DATETIME
  SET @CurrentDate = GETDATE()
  DECLARE @EndDate DATETIME
  SET @EndDate = DATEADD(year, @MaxYears, @CurrentDate)

  -- Get the set of frequencies
  DECLARE activity_cursor CURSOR FOR
  SELECT frequency_years
  FROM @frequenciesTable
  
  DECLARE @currentFrequency DECIMAL(5,2)
  DECLARE @currentYear DECIMAL(5,2)
  DECLARE @nextYearDate DATETIME

  OPEN activity_cursor
    FETCH NEXT FROM activity_cursor INTO @currentFrequency
    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @currentFrequency > @MaxYears
      BREAK

      SET @statusMessage = 'Inserting for frequency of ' + CONVERT(VARCHAR(6), @currentFrequency) + ' years'
      EXEC SP_STATUS_MESSAGE @statusMessage
      
      SET @currentYear = 0

      WHILE (@currentYear < @MaxYears)
      BEGIN
        SET @currentYear = @currentYear + @currentFrequency
        IF @currentFrequency = 0
        BEGIN
        INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
          SELECT A.compkey, A.driver_id, @currentDate, A.driver_cost, A.activity_type_id, A.alternative_id
          FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
          WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Inspection')
        INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
          SELECT A.compkey, A.driver_id, @currentDate, A.driver_cost, A.activity_type_id, A.alternative_id
          FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
          WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Cleaning')
        INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
          SELECT A.compkey, A.driver_id, @currentDate, A.driver_cost, A.activity_type_id, A.alternative_id
          FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
          WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Root Management')
        BREAK
        END
        ELSE
        BEGIN
          INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
            SELECT A.compkey, A.driver_id, [dbo].[FN_DATE_ADD_FRACTIONAL_YEARS](B.last_inspection_date, @currentYear), A.driver_cost, A.activity_type_id, A.alternative_id
            FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
            WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Inspection')
          INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
            SELECT A.compkey, A.driver_id, [dbo].[FN_DATE_ADD_FRACTIONAL_YEARS](B.last_cleaning_date, @currentYear), A.driver_cost, A.activity_type_id, A.alternative_id
            FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
            WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Cleaning')
          INSERT INTO ACTIVITIES (compkey, driver_id, activity_date, cost, activity_type_id, alternative_id)
            SELECT A.compkey, A.driver_id, [dbo].[FN_DATE_ADD_FRACTIONAL_YEARS](B.last_root_management_date, @currentYear), A.driver_cost, A.activity_type_id, A.alternative_id
            FROM (VW_CONTROLLING_DRIVERS A INNER JOIN VW_LAST_ACTIVITY_DATES B ON (A.compkey = B.compkey))
            WHERE (A.frequency_years = @currentFrequency) AND (A.activity_type = 'Root Management')
        END
      END
      FETCH NEXT FROM activity_cursor INTO @currentFrequency
    END
  CLOSE activity_cursor
  DEALLOCATE activity_cursor

  --DECLARE @cd_driver_id INT
  --DECLARE @cd_compkey INT
  --DECLARE @cd_length_ft INT
  --DECLARE @cd_diamwidth_inches DECIMAL(5,2)
  --DECLARE @cd_height_inches DECIMAL(5,2)
  --DECLARE @cd_basin VARCHAR(50)
  --DECLARE @cd_district VARCHAR(50)
  --DECLARE @cd_driver_type VARCHAR(20)
  --DECLARE @cd_driver_type_id INT
  --DECLARE @cd_driver_rank INT
  --DECLARE @cd_activity_type VARCHAR(20)
  --DECLARE @cd_activity_type_id INT
  --DECLARE @cd_cost_per_ft MONEY
  --DECLARE @cd_frequency_years DECIMAL(5,2)
  --DECLARE @cd_alternative_id INT
  --DECLARE @cd_updated_by VARCHAR(20)
  --DECLARE @cd_update_date DATETIME
  --DECLARE @cd_driver_cost MONEY
  --DECLARE @ModelDate DATETIME
  --SET @ModelDate = GETDATE()
  

  --DECLARE @driversCount BIGINT
  --EXEC @driversCount = SP_RECORD_COUNT N'DRIVERS'
  --DECLARE @currentRecordNum BIGINT
  --DECLARE @statusMessage VARCHAR(100)

  --OPEN ControllingDriversCursor
  --  FETCH NEXT FROM ControllingDriversCursor
  --  INTO @cd_driver_id, @cd_compkey, @cd_length_ft, @cd_diamwidth_inches, @cd_height_inches,
  --    @cd_basin, @cd_district, @cd_driver_type, @cd_driver_type_id, @cd_driver_rank, 
  --    @cd_activity_type, @cd_activity_type_id, @cd_cost_per_ft, @cd_frequency_years, 
  --    @cd_alternative_id, @cd_updated_by, @cd_update_date, @cd_driver_cost
  --  SET @currentRecordNum = 1

  --  SET @CurrentDate = @ModelDate
  --  WHILE @@FETCH_STATUS = 0
  --  BEGIN
  --    IF @driversCount % 1000 = 0
  --    BEGIN
  --      SET @statusMessage = 'Driver ' + CONVERT(VARCHAR(15), @currentRecordNum) + ' of ' + CONVERT(VARCHAR(15), @driversCount)
  --      EXEC SP_STATUS_MESSAGE @statusMessage
  --    END
  --    WHILE @CurrentDate < @EndDate
  --    BEGIN
  --      INSERT INTO ACTIVITIES 
  --        (
  --           compkey
  --          ,hansen_activity_code
  --          ,driver_id
  --          ,activity_date
  --          ,cost
  --          ,activity_type_id
  --          ,alternative_id
  --        )
  --        VALUES
  --        (
  --           @cd_compkey
  --          ,@cd_driver_type
  --          ,@cd_driver_id
  --          ,@CurrentDate
  --          ,@cd_driver_cost
  --          ,@cd_activity_type_id
  --          ,1
  --        )
  --      SET @CurrentDate = DATEADD(year, @cd_frequency_years ,@CurrentDate)
  --      SET @currentRecordNum = @currentRecordNum + 1
  --    END
  --    FETCH NEXT FROM ControllingDriversCursor
  --  END
  --CLOSE ControllingDriversCursor
  --DEALLOCATE ControllingDriversCursor

  EXEC SP_STATUS_MESSAGE 'End SP_FILL_ACTIVITIES'
END