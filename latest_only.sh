#!/bin/bash
set -euo pipefail

if [[ "$1" == "efile_COAK_2016_497" || "$1" == "efile_COAK_2016_496" ]]; then
  cat <<-QUERY | psql disclosure-backend
  DELETE FROM "$1" "outer"
  WHERE "Report_Num" < (
    SELECT MAX("Report_Num") FROM "$1" "inner"
      GROUP BY "FilerStateId", "Rpt_ID_Num"
      HAVING "outer"."FilerStateId" = "inner"."FilerStateId"
        AND "outer"."Rpt_ID_Num" = "inner"."Rpt_ID_Num"
    );
QUERY
else
  cat <<-QUERY | psql disclosure-backend
  DELETE FROM "$1" "outer"
  WHERE "Report_Num" < (
    SELECT MAX("Report_Num") FROM "$1" "inner"
      GROUP BY "FilerStateId", "From_Date"
      HAVING "outer"."FilerStateId" = "inner"."FilerStateId"
        AND "outer"."From_Date" = "inner"."From_Date"
    );
QUERY
fi
