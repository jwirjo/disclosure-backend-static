#!/bin/bash
set -euo pipefail

# 1. delete duplicate 497 summary
cat <<-QUERY | psql disclosure-backend
DELETE FROM "efile_COAK_2016_497" late
WHERE EXISTS (
  SELECT * FROM "efile_COAK_2016_Summary" summary
      WHERE summary."Filer_ID"::varchar = late."Filer_ID" AND late."Rpt_Date" <= summary."Thru_Date");
QUERY
