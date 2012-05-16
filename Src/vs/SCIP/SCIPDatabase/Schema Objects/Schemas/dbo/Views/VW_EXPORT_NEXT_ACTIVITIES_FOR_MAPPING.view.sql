﻿CREATE VIEW [dbo].[VW_EXPORT_NEXT_ACTIVITIES_FOR_MAPPING]
	AS
  SELECT A.COMPKEY, NEXTACTIVI, D.driver_type + ' ' + D.activity_type AS ACTIVITY, D.activity_type, D.cost, E.basin_id
FROM (((VW_NEXT_ACTIVITIES_BY_COMPKEY A INNER JOIN DRIVERS B ON (A.DRIVER_ID = B.driver_id)) INNER JOIN ACTIVITY_TYPES C ON (A.ACTIVITY_TYPE_ID = C.activity_type_id)) INNER JOIN VW_ALL_ACTIVITIES D ON (A.COMPKEY = D.COMPKEY AND A.DRIVER_ID = D.driver_id AND A.NEXTACTIVI = D.fiscal_year)) INNER JOIN BASINS E ON (D.basin = E.name)
