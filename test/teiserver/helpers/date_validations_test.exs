defmodule Teiserver.Helpers.DateValidationsTest do
  alias Teiserver.Helpers.DateValidations
  use ExUnit.Case
  import Ecto.Changeset
  @types %{start_date: :date, end_date: :date}

  setup do
    today = Date.utc_today()

    %{today: today}
  end

  describe "validate_date_order/3" do
    test "returns a valid changeset using defaults", %{today: today} do
      attrs = %{start_date: today, end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order()

      assert changeset.valid?
    end

    test "adds an error to the custom end field", %{today: today} do
      attrs = %{first: Date.add(today, 1), second: today}

      changeset =
        {%{}, %{first: :date, second: :date}}
        |> cast(attrs, [:first, :second])
        |> DateValidations.validate_date_order(:first, :second)

      refute changeset.valid?

      assert Keyword.get(changeset.errors, :second) ==
               {"Second cannot be set to earlier date than First.", []}
    end

    test "returns a valid changeset when the start date equals end date", %{today: today} do
      attrs = %{start_date: today, end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      assert changeset.valid?
    end

    test "returns an error when the start date is later than the end date", %{today: today} do
      attrs = %{start_date: Date.add(today, 1), end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      refute changeset.valid?

      assert Keyword.get(changeset.errors, :end_date) ==
               {"End date cannot be set to earlier date than Start date.", []}
    end

    test "returns a valid changeset when both dates are nil" do
      attrs = %{start_date: nil, end_date: nil}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when start date is nil", %{today: today} do
      attrs = %{start_date: nil, end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when end date is nil", %{today: today} do
      attrs = %{start_date: today, end_date: nil}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when the start date is earlier than the end date", %{
      today: today
    } do
      attrs = %{start_date: today, end_date: Date.add(today, 1)}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_order(:start_date, :end_date)

      assert changeset.valid?
    end
  end

  describe "validate_max_range/4" do
    test "returns an invalid changeset when maximum is a string", %{today: today} do
      attrs = %{start_date: Date.add(today, -500), end_date: today}
      max_range = "250"

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      assert Keyword.get(changeset.errors, :base) ==
               {"Dates too far apart, max range is 250 days.", []}

      refute changeset.valid?
    end

    test "returns a valid changeset with default range when maximum is a string not representing an integer",
         %{today: today} do
      attrs = %{start_date: Date.add(today, -500), end_date: today}
      max_range = "invalid"

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      assert Keyword.get(changeset.errors, :base) ==
               {"Dates too far apart, max range is 365 days.", []}

      refute changeset.valid?
    end

    test "returns an invalid changeset with default range when maximum is negative integer", %{
      today: today
    } do
      attrs = %{start_date: Date.add(today, -500), end_date: today}
      max_range = -200

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      assert Keyword.get(changeset.errors, :base) ==
               {"Dates too far apart, max range is 365 days.", []}

      refute changeset.valid?
    end

    test "returns a valid changeset when the range equals the maximum allowed range", %{
      today: today
    } do
      attrs = %{start_date: Date.add(today, -100), end_date: today}
      max_range = 100

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when both dates are nil" do
      attrs = %{start_date: nil, end_date: nil}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(10, :start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when start date is nil", %{today: today} do
      attrs = %{start_date: nil, end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(10, :start_date, :end_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when end date is nil", %{today: today} do
      attrs = %{start_date: today, end_date: nil}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(10, :start_date, :end_date)

      assert changeset.valid?
    end

    test "returns an error when dates are too far apart", %{today: today} do
      attrs = %{start_date: Date.add(today, -101), end_date: today}
      max_range = 100

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      refute changeset.valid?

      assert Keyword.get(changeset.errors, :base) ==
               {"Dates too far apart, max range is #{max_range} days.", []}
    end

    test "returns a valid changeset when dates are within the maximum allowed range", %{
      today: today
    } do
      attrs = %{start_date: Date.add(today, -101), end_date: today}
      max_range = 200

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(max_range, :start_date, :end_date)

      assert changeset.valid?
    end

    test "uses default field names", %{today: today} do
      attrs = %{start_date: Date.add(today, -101), end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_max_range(100)

      refute changeset.valid?
    end
  end

  describe "validate_date_not_in_future/2" do
    test "returns an error when the date is in the future", %{today: today} do
      attrs = %{start_date: Date.add(today, 100), end_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date, :end_date])
        |> DateValidations.validate_date_not_in_future(:start_date)

      refute changeset.valid?

      assert Keyword.get(changeset.errors, :start_date) == {"Cannot be set to a future date.", []}
    end

    test "returns a valid changeset when the date is nil" do
      attrs = %{start_date: nil}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date])
        |> DateValidations.validate_date_not_in_future(:start_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when the date is in the past", %{today: today} do
      attrs = %{start_date: Date.add(today, -10)}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date])
        |> DateValidations.validate_date_not_in_future(:start_date)

      assert changeset.valid?
    end

    test "returns a valid changeset when the date is today", %{today: today} do
      attrs = %{start_date: today}

      changeset =
        {%{}, @types}
        |> cast(attrs, [:start_date])
        |> DateValidations.validate_date_not_in_future(:start_date)

      assert changeset.valid?
    end
  end
end
