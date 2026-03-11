class EquityGrantsController < ApplicationController
  before_action :set_account
  before_action :set_equity_grant, only: %i[edit update destroy]

  def index
    @equity_grants = @account.accountable.equity_grants.includes(:security)
  end

  def new
    @equity_grant = @account.accountable.equity_grants.new
  end

  def create
    resolved_params = resolve_security_params(equity_grant_params)
    @equity_grant = @account.accountable.equity_grants.new(resolved_params)

    ActiveRecord::Base.transaction do
      if @equity_grant.save
        update_account_balance!
        redirect_to account_path(@account, tab: :grants), notice: "Grant created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
  end

  def update
    resolved_params = resolve_security_params(equity_grant_params)
    @equity_grant.assign_attributes(resolved_params)

    ActiveRecord::Base.transaction do
      if @equity_grant.save
        update_account_balance!
        redirect_to account_path(@account, tab: :grants), notice: "Grant updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      @equity_grant.destroy!
      update_account_balance!
    end
    redirect_to account_path(@account, tab: :grants), notice: "Grant deleted successfully."
  end

  private

    def update_account_balance!
      ec = @account.accountable
      ec.reload
      @account.update!(balance: ec.total_vested_value)
    end

    def set_account
      @account = scoped_accounts.find(params[:account_id])
      raise ActiveRecord::RecordNotFound unless @account.accountable.is_a?(EquityCompensation)
    end

    def set_equity_grant
      @equity_grant = @account.accountable.equity_grants.find(params[:id])
    end

    def equity_grant_params
      params.require(:equity_grant).permit(
        :grant_type, :name, :security_id, :grant_date, :total_units,
        :cliff_months, :vesting_period_months, :vesting_frequency,
        :strike_price, :expiration_date, :option_type, :estimated_tax_rate,
        :termination_date
      )
    end

    # The security combobox submits "TICKER|MIC" (e.g. "VCN|XTSE") instead of a UUID.
    # Resolve it to an actual Security record, creating one if needed.
    def resolve_security_params(permitted_params)
      raw_id = permitted_params[:security_id].to_s
      return permitted_params unless raw_id.include?("|")

      ticker, mic = raw_id.split("|", 2)
      security = begin
        Security.find_or_create_by!(ticker: ticker.upcase, exchange_operating_mic: mic.upcase)
      rescue ActiveRecord::RecordNotUnique
        retry
      end
      security.import_provider_details rescue nil
      permitted_params.merge(security_id: security.id)
    end
end
