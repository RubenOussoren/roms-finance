class ProjectionsController < ApplicationController
  def index
    @family = Current.family
    @projection_years = params[:projection_years]&.to_i || 10
    @tab = params[:tab]&.to_sym || :overview

    # Load all tab data - the DS::Tabs component uses client-side JS to switch tabs
    # so all content must be rendered on initial page load
    prepare_overview_data
    prepare_investments_data
    prepare_debts_data
    prepare_strategies_data
  end

  private

    def prepare_overview_data
      @net_worth_projection = FamilyProjectionCalculator.new(@family).project(years: @projection_years)
      # Single query with proper eager loading instead of N+1
      # Exclude achieved milestones and order by target_amount to show nearest goals first
      @milestones = Milestone.joins(:account)
                             .where(accounts: { family_id: @family.id })
                             .where.not(status: "achieved")
                             .includes(:account)
                             .order(:target_amount)
                             .limit(5)
      @balance_sheet = @family.balance_sheet
    end

    def prepare_investments_data
      @investment_accounts = @family.accounts
        .where(accountable_type: %w[Investment Crypto])
        .active
        .includes(:milestones)
    end

    def prepare_debts_data
      @loan_accounts = @family.accounts
        .where(accountable_type: "Loan")
        .active
        .includes(:accountable, :entries, :milestones)

      # Update milestone projections for each loan (calculates projected dates)
      @loan_accounts.each(&:update_milestone_projections!)

      @loan_payoffs = @loan_accounts.map { |a| LoanPayoffCalculator.new(a).summary }
    end

    def prepare_strategies_data
      @strategies = @family.debt_optimization_strategies.order(created_at: :desc)
    end
end
