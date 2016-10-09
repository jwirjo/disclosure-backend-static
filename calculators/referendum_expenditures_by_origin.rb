class ReferendumExpendituresByOrigin
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @ballot_measures = ballot_measures
    @committees_by_filer_id =
      committees.where('"FilerLocalId" IS NOT NULL').index_by { |c| c.FilerLocalId }
  end

  def fetch
    # Get the total expenditures.  If the contributions are less than this
    # then the remainder will be from "Unknown" locale.
    expenditures = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT "Measure_Number", "Sup_Opp_Cd", sum("Calculated_Amount") AS total
      FROM "efile_COAK_2016_E-Expenditure",
        oakland_name_to_number
      WHERE LOWER("Bal_Name") = LOWER("Measure_Name")
      AND "Cmte_Id" IS NULL
      GROUP BY "Measure_Number", "Sup_Opp_Cd";
    SQL

    contributions = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT
        expenditures."Measure_Number",
        expenditures."Sup_Opp_Cd",
        contributions_by_locale.locale,
        contributions_by_locale.total
      FROM (
        SELECT DISTINCT "FilerLocalId", "Measure_Number", "Sup_Opp_Cd"
        FROM "efile_COAK_2016_E-Expenditure"
        INNER JOIN oakland_name_to_number ON LOWER("Bal_Name") = LOWER("Measure_Name")
        WHERE "Bal_Name" IS NOT NULL
      ) expenditures,
      (
        SELECT "FilerLocalId",
        CASE
          WHEN LOWER("Tran_City") = 'oakland' THEN 'Within Oakland'
          WHEN UPPER("Tran_ST") = 'CA' THEN 'Within California'
          ELSE 'Out of State'
        END AS locale,
        SUM("Tran_Amt1") AS total
        FROM (
          SELECT "FilerLocalId", "Tran_City", "Tran_ST", "Tran_Amt1", "Tran_Id"
          FROM "efile_COAK_2016_A-Contributions"
          UNION
          SELECT "FilerLocalId"::varchar, "Tran_City", "Tran_ST", "Tran_Amt1", "Tran_Id"
          FROM "efile_COAK_2016_C-Contributions"
          UNION
          SELECT "FilerLocalId"::varchar,
            "Tran_City" as "Tran_City",
            "Tran_ST" as "Tran_ST",
            "Calculated_Amount" as "Tran_Amt1", "Tran_Id"
          FROM "efile_COAK_2016_497"
          WHERE "Form_Type" = 'F497P1'
        ) contributions
        GROUP BY "FilerLocalId", locale
      ) contributions_by_locale
      WHERE expenditures."FilerLocalId" = contributions_by_locale."FilerLocalId"
      ORDER BY expenditures."Measure_Number", expenditures."Sup_Opp_Cd", contributions_by_locale.locale;
    SQL

    support_total = {}
    oppose_total = {}

    expenditures.each do |row|
      if row['Sup_Opp_Cd'] == 'S'
        support_total[row['Measure_Number']] = row['total']
      elsif row['Sup_Opp_Cd'] == 'O'
        oppose_total[row['Measure_Number']] = row['total']
      end
    end

    support = {}
    oppose = {}

    contributions.each do |row|
      if row['Sup_Opp_Cd'] == 'S'
        support[row['Measure_Number']] ||= {}
        support[row['Measure_Number']][row['locale']] = row['total']
      elsif row['Sup_Opp_Cd'] == 'O'
        oppose[row['Measure_Number']] ||= {}
        oppose[row['Measure_Number']][row['locale']] = row['total']
      end
    end

    [
      [support_total, support, :supporting_locales, :supporting_total],
      [oppose_total, oppose, :opposing_locales, :opposing_total],
    ].each do |expenditures, locales, calculation_name, total_name|
      expenditures.keys.each do |measure|
        total = 0
        ballot_measure = ballot_measure_from_number(measure)
        result = locales[measure].keys.map do |locale|
          amount = locales[measure][locale]
          expenditures[measure] -= amount
          total += amount
          {
            locale: locale,
            amount: amount,
          }
        end
        if expenditures[measure] > 0
          total += expenditures[measure]
          result << {
            locale: 'Unknown',
            amount: expenditures[measure],
          }
        end
        ballot_measure.save_calculation(total_name, total)
        ballot_measure.save_calculation(calculation_name, result)
      end
    end
  end
  def ballot_measure_from_number(bal_number)
    @ballot_measures.detect do |measure|
      measure['Measure_number'] == bal_number
    end
  end
end
