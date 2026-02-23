class ProjectionsController < ApplicationController
  layout -> { false if turbo_frame_request? }

  def index
    @family = Current.family
    @projection_years = params[:projection_years]&.to_i || 10
    @tab = params[:tab] || "overview"
    @scope = valid_scope_param
    @show_scope_toggle = @family.multi_user?

    case @tab
    when "overview"    then prepare_overview_data
    when "investments" then prepare_investments_data
    when "debts"       then prepare_debts_data
    when "strategies"  then prepare_strategies_data
    end
  end

  private

    def prepare_overview_data
      cache_key = projection_cache_key("overview_#{@projection_years}")
      @net_worth_projection = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        FamilyProjectionCalculator.new(@family, viewer: Current.user, scope: @scope).project(years: @projection_years)
      end
      # Single query with proper eager loading instead of N+1
      # Exclude achieved milestones and order by target_amount to show nearest goals first
      @milestones = Milestone.joins(:account)
                             .where(accounts: { id: scope_filtered_accounts.select(:id) })
                             .where.not(status: "achieved")
                             .includes(:account)
                             .order(:target_amount)
                             .limit(5)
      @balance_sheet = @family.balance_sheet_for(Current.user, scope: @scope)
    end

    def prepare_investments_data
      @investment_accounts = scope_filtered_accounts
        .where(accountable_type: %w[Investment Crypto])
        .active
        .includes(:milestones, :account_ownerships)
      @investment_total = compute_scoped_total(@investment_accounts)
    end

    def prepare_debts_data
      @loan_accounts = scope_filtered_accounts
        .where(accountable_type: "Loan")
        .active
        .includes(:accountable, :milestones, :projection_assumption, :account_ownerships)

      # Milestone projections are updated via background job (UpdateMilestoneProjectionsJob)
      # triggered by balance changes, avoiding N+1 updates in the request cycle

      @loan_payoffs = @loan_accounts.map { |a| LoanPayoffCalculator.new(a).summary }
      @debt_total = compute_scoped_total(@loan_accounts).abs
    end

    def prepare_strategies_data
      strategies = @family.debt_optimization_strategies.order(created_at: :desc)
      if @scope == :personal
        personal_loan_ids = scope_filtered_accounts.where(accountable_type: "Loan").active.select(:id)
        strategies = strategies.where(primary_mortgage_id: personal_loan_ids)
      end
      @strategies = strategies
    end

    def valid_scope_param
      scope = params[:scope]
      %w[personal household].include?(scope) ? scope.to_sym : :household
    end

    def scope_filtered_accounts
      @scope == :personal ? Current.family.accounts.with_ownership_for(Current.user) : scoped_accounts
    end

    def compute_scoped_total(accounts)
      if @scope == :personal
        member_count = @family.users.count
        accounts.sum { |a| a.balance * a.ownership_fraction_for(Current.user, member_count: member_count) }
      else
        accounts.sum(&:balance)
      end
    end

    # Cache key that invalidates when:
    # 1. Account data syncs (latest_sync_completed_at via build_cache_key)
    # 2. Account records change (accounts.maximum(:updated_at) via build_cache_key)
    # 3. Projection assumptions change (projection_assumptions.maximum(:updated_at))
    def projection_cache_key(suffix)
      base = @family.build_cache_key("projection_#{suffix}", invalidate_on_data_updates: true)
      pa_version = @family.projection_assumptions.maximum(:updated_at)&.to_i || 0
      "#{base}_pa#{pa_version}_scope#{@scope}_user#{Current.user.id}"
    end
end
