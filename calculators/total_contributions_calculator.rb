require 'set'

class TotalContributionsCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC.to_s }
    @candidate_committees_by_netfile_id =
      committees.where("\"FilerLocalId\" IS NOT NULL AND \"FilerStateId\" IN ('#{@candidates_by_filer_id.keys.join "','"}')").index_by { |c| c.FilerLocalId }

  end

  def fetch
    contributions_by_netfile_id = {}

    summary_results = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "FilerLocalId", SUM("Amount_A") AS "Amount_A"
      FROM "efile_COAK_2016_Summary"
      WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "', '"}')
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '5'
      GROUP BY "FilerLocalId"
      ORDER BY "FilerLocalId"
    SQL

    summary_results.each do |result|
      netfile_id = result['FilerLocalId'].to_s
      contributions_by_netfile_id[netfile_id] ||= 0
      contributions_by_netfile_id[netfile_id] += result['Amount_A'].to_f
    end

    # NOTE: We remove duplicate transactions on 497 that are also reported on
    # Schedule A during a preprocssing script. (See
    # `./../remove_duplicate_transactionts.sh`)
    late_results = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT "FilerLocalId", SUM("Calculated_Amount") AS "Total"
      FROM "efile_COAK_2016_497"
      WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
      AND "Form_Type" = 'F497P1'
      GROUP BY "FilerLocalId"
      ORDER BY "FilerLocalId"
    SQL

    late_results.index_by { |row| row['FilerLocalId'].to_s }.each do |netfile_id, result|
      contributions_by_netfile_id[netfile_id] ||= 0
      contributions_by_netfile_id[netfile_id] += result['Total'].to_f
    end

    contributions_by_netfile_id.each do |netfile_id, total_contributions|
      committee = @candidate_committees_by_netfile_id[netfile_id]
      candidate = @candidates_by_filer_id[committee.FilerStateId]
      candidate.save_calculation(:total_contributions, total_contributions)
    end
  end
end

