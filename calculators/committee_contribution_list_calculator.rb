class CommitteeContributionListCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @committees = committees
  end

  def fetch
    results = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT "Filer_ID", "Tran_Amt1", "Tran_Date", "Tran_NamF", "Tran_NamL"
      FROM combined_contributions
      WHERE "Filer_ID" IN (#{filer_ids})
      ORDER BY "Tran_Date", "Tran_NamL", "Tran_NamF", "Tran_Amt1"
    SQL

    contributions_by_committee = results.each_with_object({}) do |row, hash|
      filer_id = row['Filer_ID'].to_s

      hash[filer_id] ||= []
      hash[filer_id] << row
    end

    @committees.each do |committee|
      filer_id = committee['Filer_ID'].to_s
      sorted = Array(contributions_by_committee[filer_id])

      committee.save_calculation(:contribution_list, sorted)
    end
  end

  def filer_ids
    @committees.map(&:Filer_ID).map { |f| "'#{f}'::varchar" }.join(',')
  end
end
