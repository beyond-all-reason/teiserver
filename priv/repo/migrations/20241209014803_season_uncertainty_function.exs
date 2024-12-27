defmodule Teiserver.Repo.Migrations.SeasonUncertaintyFunction do
  use Ecto.Migration

  def up do
    query = """
    create or replace function calculate_season_uncertainty(current_uncertainty float, last_updated timestamp, min_uncertainty float default 5)
       returns float
       language plpgsql
      as
    $$
    declare
       -- variable declaration
    	default_uncertainty float;
    	days_not_played float;
    	one_month float;
    	one_year float;
    	interpolated_uncertainty float;
    	min_days float;
    	max_days float;
    	max_uncertainty float;
    begin
       -- Your new uncertainty will be: greatest(target_uncertainty, current_uncertainty)
    	-- Where target_uncertainty will be default if you have not played for over a year
    	-- 5 (min_uncertainty) if you have played within one month
    	-- And use linear interpolation for values in between
    	one_year = 365.0;
    	default_uncertainty = 25.0/3;
    	one_month = one_year / 12;
    	days_not_played = abs(DATE_PART('day', (now()- last_updated )));
    	min_days = one_month;
    	max_days = one_year;
    	max_uncertainty = default_uncertainty;

    	if(days_not_played >= max_days) then
    		return default_uncertainty;
    	elsif days_not_played <= min_days then
    		return GREATEST(current_uncertainty, min_uncertainty);
    	else
    		-- Use linear interpolation
    		interpolated_uncertainty =  min_uncertainty +(days_not_played - min_days) * (max_uncertainty - min_uncertainty) /(max_days - min_days);

            return GREATEST(current_uncertainty, interpolated_uncertainty);

    	end if;
     end;
    $$;


    """

    execute(query)
  end

  def down do
    query = "drop function calculate_season_uncertainty"
    execute(query)
  end
end
