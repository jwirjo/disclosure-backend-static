class CandidateExpendituresByType
  TYPE_DESCRIPTIONS = {
    'CMP' => 'Campaign Paraphernalia/Misc.',
    'CNS' => 'Campaign Consultants',
    'CTB' => 'Contribution',
    'CVC' => 'Civic Donations',
    'FIL' => 'Candidate Filing/Ballot Fees',
    'FND' => 'Fundraising Events',
    'IND' => 'Independent Expenditure Supporting/Opposing Others',
    'LEG' => 'Legal Defense',
    'LIT' => 'Campaign Literature and Mailings',
    'MBR' => 'Member Communications',
    'MTG' => 'Meetings and Appearances',
    'OFC' => 'Office Expenses',
    'PET' => 'Petition Circulating',
    'PHO' => 'Phone Banks',
    'POL' => 'Polling and Survey Research',
    'POS' => 'Postage, Delivery and Messenger Services',
    'PRO' => 'Professional Services (Legal, Accounting)',
    'PRT' => 'Print Ads',
    'RAD' => 'Radio Airtime and Production Costs',
    'RFD' => 'Returned Contributions',
    'SAL' => "Campaign Workers' Salaries",
    'TEL' => 'T.V. or Cable Airtime and Production Costs',
    'TRC' => 'Candidate Travel, Lodging, and Meals',
    'TRS' => 'Staff/Spouse Travel, Lodging, and Meals',
    'TSF' => 'Transfer Between Committees of the Same Candidate/sponsor',
    'VOT' => 'Voter Registration',
    'WEB' => 'Information Technology Costs (Internet, E-mail)',
    '' => 'Not Stated'
  }

  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC }
    @candidate_committees_by_netfile_id =
      committees.where("\"FilerLocalId\" IS NOT NULL AND \"FilerStateId\" IN ('#{@candidates_by_filer_id.keys.join "','"}')").index_by { |c| c.FilerLocalId }
  end

  def fetch
    # normalization: replace three-letter names with TYPE_DESCRIPTIONS
    TYPE_DESCRIPTIONS.each do |short_name, human_name|
      expenditures_by_candidate_by_type.each do |netfile_id, expenditures_by_type|
        if value = expenditures_by_type.delete(short_name)
          expenditures_by_type[human_name] = value
        end
      end
      opposing_candidate_by_type.each do |netfile_id, expenditures_by_type|
        if value = expenditures_by_type.delete(short_name)
          expenditures_by_type[human_name] = value
        end
      end
    end

    # save!
    expenditures_by_candidate_by_type.each do |netfile_id, expenditures_by_type|
      committee = @candidate_committees_by_netfile_id[netfile_id]
      candidate = @candidates_by_filer_id[committee.FilerStateId.to_i]
      candidate.save_calculation(:expenditures_by_type, expenditures_by_type)
    end
    opposing_candidate_by_type.each do |netfile_id, expenditures_by_type|
      committee = @candidate_committees_by_netfile_id[netfile_id]
      candidate = @candidates_by_filer_id[committee.FilerStateId.to_i]
      candidate.save_calculation(:opposing_by_type, expenditures_by_type)
    end
  end

  private

  def expenditures_by_candidate_by_type
    @_expenditures_by_candidate_by_type ||= {}.tap do |hash|
      # Include expenses from the 24 hour IE report on FORM 496
      # except those that are already in Schedule E.  Note that
      # Tran_Code is not set in 496 so we cannot just UNION them out.
      results = ActiveRecord::Base.connection.execute <<-SQL
        SELECT "FilerLocalId", "Tran_Code", SUM("Calculated_Amount") AS "Total"
        FROM
          (
          SELECT "FilerLocalId", "Tran_Code", "Calculated_Amount"
          FROM "efile_COAK_2016_E-Expenditure"
          UNION ALL
          SELECT "FilerLocalId", '' AS "Tran_Code", "Calculated_Amount"
          FROM "efile_COAK_2016_496" AS "outer", "oakland_candidates"
          WHERE "Sup_Opp_Cd" = 'S'
          AND lower("Candidate") = lower(trim(concat("Cand_NamF", ' ', "Cand_NamL")))
          AND NOT EXISTS (SELECT 1 from "efile_COAK_2016_E-Expenditure" AS "inner"
              WHERE "outer"."FilerLocalId"::varchar = "inner"."FilerLocalId"
              AND "outer"."Tran_Date" = "inner"."Tran_Date"
              AND "outer"."Calculated_Amount" = "inner"."Calculated_Amount"
              AND "outer"."Cand_NamL" = "inner"."Cand_NamL")
          ) U
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        GROUP BY "Tran_Code", "FilerLocalId"
        ORDER BY "Tran_Code", "FilerLocalId"
      SQL

      # 497 does not contain "Tran_Code" making this calculator pretty useless
      # for those contributions.
      # To make the numbers line up closer, we'll bucket those all under "Not
      # Stated".
      late_expenditures = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT "FilerLocalId", '' AS "Tran_Code", SUM("Calculated_Amount") AS "Total"
        FROM "efile_COAK_2016_497"
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        AND "Form_Type" = 'F497P2'
        GROUP BY "FilerLocalId"
        ORDER BY "FilerLocalId"
      SQL

      (results.to_a + late_expenditures.to_a).each do |result|
        hash[result['FilerLocalId']] ||= {}
        hash[result['FilerLocalId']][result['Tran_Code']] = result['Total']
      end
    end
  end


  def opposing_candidate_by_type
    @_opposing_candidate_by_type ||= {}.tap do |hash|
      # Include expenses from the 24 hour IE report on FORM 496
      # except those that are already in Schedule E.  Note that
      # Tran_Code is not set in 496 so we cannot just UNION them out.
      results = ActiveRecord::Base.connection.execute <<-SQL
        SELECT "FilerLocalId", "Tran_Code", SUM("Calculated_Amount") AS "Total"
        FROM
          (SELECT "FilerLocalId", "Tran_Code", "Calculated_Amount"
          FROM "efile_COAK_2016_E-Expenditure", "oakland_candidates"
          WHERE "Sup_Opp_Cd" = 'O'
          AND lower("Candidate") = lower(trim(concat("Cand_NamF", ' ', "Cand_NamL")))
          UNION ALL
          SELECT "FilerLocalId", '' AS "Tran_Code", "Calculated_Amount"
          FROM "efile_COAK_2016_496" AS "outer", "oakland_candidates"
          WHERE "Sup_Opp_Cd" = 'O'
          AND lower("Candidate") = lower(trim(concat("Cand_NamF", ' ', "Cand_NamL")))
          AND NOT EXISTS (SELECT 1 from "efile_COAK_2016_E-Expenditure" AS "inner"
              WHERE "outer"."FilerLocalId"::varchar = "inner"."FilerLocalId"
              AND "outer"."Tran_Date" = "inner"."Tran_Date"
              AND "outer"."Calculated_Amount" = "inner"."Calculated_Amount"
              AND "outer"."Cand_NamL" = "inner"."Cand_NamL")
          ) U
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        GROUP BY "Tran_Code", "FilerLocalId"
        ORDER BY "Tran_Code", "FilerLocalId"
      SQL

      results.to_a.each do |result|
        hash[result['FilerLocalId']] ||= {}
        hash[result['FilerLocalId']][result['Tran_Code']] = result['Total']
      end
    end
  end
end
