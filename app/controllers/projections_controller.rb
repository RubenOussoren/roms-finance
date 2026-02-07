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
      cache_key = projection_cache_key("overview_#{@projection_years}")
      @net_worth_projection = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        FamilyProjectionCalculator.new(@family).project(years: @projection_years)
      end
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
        .includes(:accountable, :milestones, :projection_assumption)

      # Milestone projections are updated via background job (UpdateMilestoneProjectionsJob)
      # triggered by balance changes, avoiding N+1 updates in the request cycle

      @loan_payoffs = @loan_accounts.map { |a| LoanPayoffCalculator.new(a).summary }
    end

    def prepare_strategies_data
      @strategies = @family.debt_optimization_strategies.order(created_at: :desc)
    end

    # Cache key that invalidates when:
    # 1. Account data syncs (latest_sync_completed_at via build_cache_key)
    # 2. Account records change (accounts.maximum(:updated_at) via build_cache_key)
    # 3. Projection assumptions change (projection_assumptions.maximum(:updated_at))
    def projection_cache_key(suffix)
      base = @family.build_cache_key("projection_#{suffix}", invalidate_on_data_updates: true)
      pa_version = @family.projection_assumptions.maximum(:updated_at)&.to_i || 0
      "#{base}_pa#{pa_version}"
    end
end
