#!/bin/bash
set -euo pipefail

# 1. delete duplicate A/497 contributions
cat <<-QUERY | psql disclosure-backend
DELETE FROM "efile_COAK_2016_497" late
USING "efile_COAK_2016_A-Contributions" contributions
WHERE contributions."FilerLocalId"::varchar = late."FilerLocalId"::varchar
AND (
  contributions."Tran_Id" = late."Tran_Id"
  OR (LOWER(contributions."Tran_NamL") = LOWER(late."Tran_NamL") AND contributions."Tran_Amt1" = late."Calculated_Amount")
)
AND late."Form_Type" = 'F497P1';
QUERY

# 2. delete duplicate C/497 contributions
cat <<-QUERY | psql disclosure-backend
DELETE FROM "efile_COAK_2016_497" late
USING "efile_COAK_2016_C-Contributions" contributions
WHERE contributions."FilerLocalId"::varchar = late."FilerLocalId"::varchar
AND (
  contributions."Tran_Id" = late."Tran_Id"
  OR (LOWER(contributions."Tran_NamL") = LOWER(late."Tran_NamL") AND contributions."Tran_Amt1" = late."Calculated_Amount")
)
AND late."Form_Type" = 'F497P1';
QUERY

# 3. delete duplicate E/497 expenditures
cat <<-QUERY | psql disclosure-backend
DELETE FROM "efile_COAK_2016_497" late
USING "efile_COAK_2016_E-Expenditure" expenditures
WHERE expenditures."FilerLocalId"::varchar = late."FilerLocalId"::varchar
AND (
  expenditures."Tran_Id" = late."Tran_Id"
  OR (LOWER(expenditures."Tran_NamL") = LOWER(late."Tran_NamL") AND expenditures."Calculated_Amount" = late."Calculated_Amount")
)
AND late."Form_Type" = 'F497P2';
QUERY
