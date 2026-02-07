# 🇨🇦 Controller for Canadian Modified Smith Manoeuvre and debt optimization strategies
class DebtOptimizationStrategiesController < ApplicationController
  before_action :set_strategy, only: %i[show edit update destroy simulate]
  helper_method :status_badge_classes, :strategy_type_label, :months_to_years

  def index
    @strategies = family.debt_optimization_strategies.order(created_at: :desc)
  end

  def show
    @chart_series = @strategy.chart_series_builder.all_series if @strategy.simulated? || @strategy.active?
    @summary_metrics = @strategy.chart_series_builder.summary_metrics if @chart_series.present?
    @baseline_entries = @strategy.baseline_entries.limit(24)
    @strategy_entries = @strategy.strategy_entries.limit(24)
  end

  def new
    @strategy = family.debt_optimization_strategies.new(
      strategy_type: "modified_smith",
      currency: family.currency,
      simulation_months: 300
    )
    @loan_accounts = family.accounts.where(accountable_type: "Loan")
  end

  def create
    @strategy = family.debt_optimization_strategies.new(strategy_params)
    @strategy.currency = family.currency

    if @strategy.save
      create_default_auto_stop_rules(@strategy)
      redirect_to debt_optimization_strategy_path(@strategy), notice: "Strategy created successfully"
    else
      @loan_accounts = family.accounts.where(accountable_type: "Loan")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @loan_accounts = family.accounts.where(accountable_type: "Loan")
  end

  def update
    if @strategy.update(strategy_params)
      redirect_to debt_optimization_strategy_path(@strategy), notice: "Strategy updated successfully"
    else
      @loan_accounts = family.accounts.where(accountable_type: "Loan")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @strategy.destroy
    redirect_to debt_optimization_strategies_path, notice: "Strategy deleted successfully"
  end

  def simulate
    @strategy.run_simulation!
    redirect_to debt_optimization_strategy_path(@strategy), notice: "Simulation completed successfully"
  rescue => e
    redirect_to debt_optimization_strategy_path(@strategy), alert: "Simulation failed: #{e.message}"
  end

  private

    def family
      Current.family
    end

    def set_strategy
      @strategy = family.debt_optimization_strategies.find(params[:id])
    end

    def strategy_params
      params.require(:debt_optimization_strategy).permit(
        :name,
        :strategy_type,
        :province,
        :primary_mortgage_id,
        :heloc_id,
        :rental_mortgage_id,
        :rental_income,
        :rental_expenses,
        :heloc_interest_rate,
        :simulation_months
      )
    end

    def create_default_auto_stop_rules(strategy)
      # Default rule: stop when HELOC reaches 95% of limit
      strategy.auto_stop_rules.create!(
        rule_type: "heloc_limit_percentage",
        threshold_value: 95,
        threshold_unit: "percentage",
        enabled: true
      )

      # Default rule: stop when primary mortgage is paid off
      strategy.auto_stop_rules.create!(
        rule_type: "primary_paid_off",
        enabled: true
      )
    end

    def status_badge_classes(strategy)
      case strategy.status
      when "simulated"
        "bg-blue-100 text-blue-700"
      when "active"
        "bg-green-100 text-green-700"
      when "completed"
        "bg-gray-100 text-secondary"
      else
        "bg-yellow-100 text-yellow-700"
      end
    end

    def strategy_type_label(strategy)
      case strategy.strategy_type
      when "baseline"
        "Baseline (No Optimization)"
      when "modified_smith"
        "Modified Smith Manoeuvre"
      else
        strategy.strategy_type.titleize
      end
    end

    def months_to_years(months)
      return "—" unless months.present? && months > 0
      years = months / 12
      remaining_months = months % 12

      if years > 0 && remaining_months > 0
        "#{years}y #{remaining_months}m"
      elsif years > 0
        "#{years} years"
      else
        "#{months} months"
      end
    end
end
