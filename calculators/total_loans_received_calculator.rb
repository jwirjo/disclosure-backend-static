class TotalLoansReceivedCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC.to_s }
    @candidate_committees_by_netfile_id =
      committees.where("\"FilerLocalId\" IS NOT NULL AND \"FilerStateId\" IN ('#{@candidates_by_filer_id.keys.join "','"}')").index_by { |c| c.FilerLocalId }
  end

  def fetch
    @results = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT "FilerLocalId", SUM("Amount_A") AS "Amount_A"
      FROM "efile_COAK_2016_Summary"
      WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "', '"}')
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '2'
      GROUP BY "FilerLocalId"
      ORDER BY "FilerLocalId"
    SQL

    @results.each do |row|
      committee = @candidate_committees_by_netfile_id[row['FilerLocalId']]
      candidate = @candidates_by_filer_id[committee.FilerStateId]
      candidate.save_calculation(:total_loans_received, row['Amount_A'].to_f)
    end
  end
end
