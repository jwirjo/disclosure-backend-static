class TotalExpendituresCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC }
  end

  def fetch
    results = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "FilerLocalId", SUM("Amount_A") AS "Amount_A"
      FROM "efile_COAK_2016_Summary"
      WHERE "FilerLocalId" IN ('#{@candidates_by_filer_id.keys.join "', '"}')
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '11'
      GROUP BY "FilerLocalId"
      ORDER BY "FilerLocalId"
    SQL

    late_expenditures = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "FilerLocalId", SUM("Calculated_Amount") AS "Amount_A"
      FROM "efile_COAK_2016_497"
      WHERE "FilerLocalId" IN ('#{@candidates_by_filer_id.keys.join "', '"}')
      AND "Form_Type" = 'F497P2'
      GROUP BY "FilerLocalId"
      ORDER BY "FilerLocalId"
    SQL

    (results.to_a + late_expenditures.to_a).each do |result|
      candidate = @candidates_by_filer_id[result['FilerLocalId'].to_i]
      candidate.save_calculation(:total_expenditures, result['Amount_A'])
    end
  end
end

