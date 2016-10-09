class CommitteeContributionListCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @committees = committees
  end

  def fetch
    results = ActiveRecord::Base.connection.execute(<<-SQL)
      -- Schedule A Monetary Contributions
      SELECT "FilerStateId"::varchar, "FilerLocalId"::varchar, "Tran_Amt1", "Tran_NamF", "Tran_NamL", "Tran_Date"
      FROM "efile_COAK_2016_A-Contributions"
      WHERE "FilerLocalId"::varchar IN (#{netfile_ids})
      UNION

      -- Schedule C In-Kind contributions
      SELECT "FilerStateId"::varchar, "FilerLocalId"::varchar, "Tran_Amt1", "Tran_NamF", "Tran_NamL", "Tran_Date"
      FROM "efile_COAK_2016_C-Contributions"
      WHERE "FilerLocalId"::varchar IN (#{netfile_ids})
      UNION

      -- Form 497 Late Contributions
      SELECT
        "FilerStateId"::varchar,
        "FilerLocalId"::varchar,
        "Calculated_Amount" AS "Tran_Amt1",
        "Tran_NamF" AS "Tran_NamF",
        "Tran_NamL" AS "Tran_NamL",
        "Tran_Date" AS "Tran_Date"
      FROM "efile_COAK_2016_497"
      WHERE "Form_Type" = 'F497P1'
      AND "FilerLocalId"::varchar IN (#{netfile_ids})

      ORDER BY "Tran_Date", "Tran_Amt1", "Tran_NamF", "Tran_NamL"
    SQL

    contributions_by_committee = results.each_with_object({}) do |row, hash|
      netfile_id = row['FilerLocalId'].to_s

      hash[netfile_id] ||= []
      hash[netfile_id] << row
    end

    @committees.each do |committee|
      netfile_id = committee['FilerLocalId'].to_s
      sorted =
        Array(contributions_by_committee[netfile_id]).sort_by { |row| row['Tran_NamL'] }

      committee.save_calculation(:contribution_list, sorted)
    end
  end

  def netfile_ids
    @committees.map(&:FilerLocalId).map { |f| "'#{f}'::varchar" }.join(',')
  end
end
