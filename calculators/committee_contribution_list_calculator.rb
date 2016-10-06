class CommitteeContributionListCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @committees = committees
  end

  def fetch
    results = ActiveRecord::Base.connection.execute(<<-SQL)
      -- Schedule A Monetary Contributions
      SELECT "FilerStateId"::varchar, "Tran_Amt1", "Tran_NamF", "Tran_NamL", "Tran_Date"
      FROM "efile_COAK_2016_A-Contributions"
      WHERE "FilerStateId"::varchar IN (#{filer_ids})
      UNION

      -- Schedule C In-Kind contributions
      SELECT "FilerStateId"::varchar, "Tran_Amt1", "Tran_NamF", "Tran_NamL", "Tran_Date"
      FROM "efile_COAK_2016_C-Contributions"
      WHERE "FilerStateId"::varchar IN (#{filer_ids})
      UNION

      -- Form 497 Late Contributions
      SELECT
        "FilerStateId"::varchar,
        "Amount" AS "Tran_Amt1",
        "Enty_NamF" AS "Tran_NamF",
        "Tran_NamL" AS "Tran_NamL",
        "Ctrib_Date" AS "Tran_Date"
      FROM "efile_COAK_2016_497"
      WHERE "Form_Type" = 'F497P1'
      AND "FilerStateId"::varchar IN (#{filer_ids})

      ORDER BY "Tran_Date", "Tran_Amt1", "Tran_NamF", "Tran_NamL"
    SQL

    contributions_by_committee = results.each_with_object({}) do |row, hash|
      filer_id = row['FilerStateId'].to_s

      hash[filer_id] ||= []
      hash[filer_id] << row
    end

    @committees.each do |committee|
      filer_id = committee['FilerStateId'].to_s
      sorted =
        Array(contributions_by_committee[filer_id]).sort_by { |row| row['Tran_NamL'] }

      committee.save_calculation(:contribution_list, sorted)
    end
  end

  def filer_ids
    @committees.map(&:FilerStateId).map { |f| "'#{f}'::varchar" }.join(',')
  end
end
