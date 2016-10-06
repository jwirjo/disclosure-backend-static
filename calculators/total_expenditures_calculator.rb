class TotalExpendituresCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC }
  end

  def fetch
    results = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "FilerStateId", SUM("Amount_A") AS "Amount_A"
      FROM "efile_COAK_2016_Summary"
      WHERE "FilerStateId" IN ('#{@candidates_by_filer_id.keys.join "', '"}')
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '11'
      GROUP BY "FilerStateId"
      ORDER BY "FilerStateId"
    SQL

    late_expenditures = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "FilerStateId", SUM("Amount") AS "Amount_A"
      FROM "efile_COAK_2016_497"
      WHERE "FilerStateId" IN ('#{@candidates_by_filer_id.keys.join "', '"}')
      AND "Form_Type" = 'F497P2'
      GROUP BY "FilerStateId"
      ORDER BY "FilerStateId"
    SQL

    (results.to_a + late_expenditures.to_a).each do |result|
      candidate = @candidates_by_filer_id[result['FilerStateId'].to_i]
      candidate.save_calculation(:total_expenditures, result['Amount_A'])
    end
  end
end

