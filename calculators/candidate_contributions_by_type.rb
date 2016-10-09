class CandidateContributionsByType
  TYPE_DESCRIPTIONS = {
    'IND' => 'Individual',
    'COM' => 'Committee',
    'OTH' => 'Other (includes Businesses)',
  }

  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC }
    @candidate_committees_by_netfile_id =
      committees.where("\"FilerLocalId\" IS NOT NULL AND \"FilerStateId\" IN ('#{@candidates_by_filer_id.keys.join "','"}')").index_by { |c| c.FilerLocalId }
  end

  def fetch
    # normalization: lump in "SCC" (small contributor committee) with "COM"
    contributions_by_candidate_by_type.each do |netfile_id, contributions_by_type|
      if small_contributor_committee = contributions_by_type.delete('SCC')
        contributions_by_type['COM'] ||= 0
        contributions_by_type['COM'] += small_contributor_committee.to_f
      end
    end

    # normalization: fetch unitemized totals and add it as a bucket too
    unitemized_contributions_by_candidate.each do |netfile_id, unitemized_contributions|
      contributions_by_candidate_by_type[netfile_id] ||= {}
      contributions_by_candidate_by_type[netfile_id]['Unitemized'] = unitemized_contributions.to_f
    end

    # normalization: replace three-letter names with TYPE_DESCRIPTIONS
    TYPE_DESCRIPTIONS.each do |short_name, human_name|
      contributions_by_candidate_by_type.each do |netfile_id, contributions_by_type|
        if value = contributions_by_type.delete(short_name)
          contributions_by_type[human_name] = value
        end
      end
    end

    # save!
    contributions_by_candidate_by_type.each do |netfile_id, contributions_by_type|
      committee = @candidate_committees_by_netfile_id[netfile_id]
      candidate = @candidates_by_filer_id[committee.FilerStateId.to_i]
      candidate.save_calculation(:contributions_by_type, contributions_by_type)
    end
  end

  private

  def contributions_by_candidate_by_type
    @_contributions_by_candidate_by_type ||= {}.tap do |hash|
      monetary_results = ActiveRecord::Base.connection.execute <<-SQL
        SELECT "FilerLocalId", "Entity_Cd", SUM("Tran_Amt1") AS "Total"
        FROM "efile_COAK_2016_A-Contributions"
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        GROUP BY "Entity_Cd", "FilerLocalId"
        ORDER BY "Entity_Cd", "FilerLocalId"
      SQL

      in_kind_results = ActiveRecord::Base.connection.execute <<-SQL
        SELECT "FilerLocalId", "Entity_Cd", SUM("Tran_Amt1") AS "Total"
        FROM "efile_COAK_2016_C-Contributions"
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        GROUP BY "Entity_Cd", "FilerLocalId"
        ORDER BY "Entity_Cd", "FilerLocalId"
      SQL

      # NOTE: We remove duplicate transactions on 497 that are also reported on
      # Schedule A during a preprocssing script. (See
      # `./../remove_duplicate_transactionts.sh`)
      late_results = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT "FilerLocalId", "Entity_Cd", SUM("Calculated_Amount") AS "Total"
        FROM "efile_COAK_2016_497"
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
        AND "Form_Type" = 'F497P1'
        GROUP BY "Entity_Cd", "FilerLocalId"
        ORDER BY "Entity_Cd", "FilerLocalId"
      SQL

      (monetary_results.to_a + in_kind_results.to_a + late_results.to_a).each do |result|
        netfile_id = result['FilerLocalId'].to_s

        hash[netfile_id] ||= {}
        hash[netfile_id][result['Entity_Cd']] ||= 0
        hash[netfile_id][result['Entity_Cd']] += result['Total']
      end
    end
  end

  def unitemized_contributions_by_candidate
    @_unitemized_contributions_by_candidate ||= {}.tap do |hash|
      results = ActiveRecord::Base.connection.execute <<-SQL
        SELECT "FilerLocalId", SUM("Amount_A") AS "Amount_A" FROM "efile_COAK_2016_Summary"
        WHERE "FilerLocalId" IN ('#{@candidate_committees_by_netfile_id.keys.join "','"}')
          AND "Form_Type" = 'A' AND "Line_Item" = '2'
        GROUP BY "FilerLocalId"
        ORDER BY "FilerLocalId"
      SQL

      hash.merge!(Hash[results.map { |row| row.values_at('FilerLocalId', 'Amount_A') }])
    end
  end
end
