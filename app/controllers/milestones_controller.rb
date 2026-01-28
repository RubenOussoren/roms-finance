class MilestonesController < ApplicationController
  before_action :set_account, only: %i[index new create]
  before_action :set_milestone, only: %i[edit update destroy]

  def index
    @milestones = @account.milestones.ordered_by_target
  end

  def new
    target_type = Milestone.default_target_type_for(@account)

    @milestone = @account.milestones.new(
      currency: @account.currency,
      status: "pending",
      target_type: target_type
    )

    # For debt milestones, pre-set the starting balance
    if target_type == "reduce_to"
      @milestone.starting_balance = @account.balance.abs
    end
  end

  def edit
    @account = @milestone.account
  end

  def create
    @milestone = @account.milestones.new(milestone_params.except(:target_percentage))
    @milestone.currency ||= @account.currency
    @milestone.is_custom = true
    @milestone.status = "pending"

    # Auto-set target_type based on account if not provided
    @milestone.target_type ||= Milestone.default_target_type_for(@account)

    # For reduction milestones, calculate target_amount from percentage
    if @milestone.reduction_milestone?
      @milestone.starting_balance ||= @account.balance.abs

      if params[:milestone][:target_percentage].present?
        percentage = params[:milestone][:target_percentage].to_d
        # target_amount = starting_balance * (1 - percentage/100)
        # e.g., 50% paid means target is 50% of starting (half remaining)
        @milestone.target_amount = (@milestone.starting_balance * (1 - percentage / 100)).round(2)
      end
    end

    if @milestone.save
      @milestone.update_progress!(@account.balance)
      return_path = params[:return_to].presence || account_path(@account)

      respond_to do |format|
        format.html { redirect_to return_path, notice: "Milestone created" }
        format.turbo_stream { stream_redirect_to return_path }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    update_params = milestone_params.except(:target_percentage)

    # For reduction milestones, recalculate target_amount from percentage
    if @milestone.reduction_milestone? && params[:milestone][:target_percentage].present?
      percentage = params[:milestone][:target_percentage].to_d
      starting = @milestone.starting_balance || @milestone.account.balance.abs
      update_params[:target_amount] = (starting * (1 - percentage / 100)).round(2)
    end

    if @milestone.update(update_params)
      @milestone.update_progress!(@milestone.account.balance)
      return_path = params[:return_to].presence || account_path(@milestone.account)

      respond_to do |format|
        format.html { redirect_to return_path, notice: "Milestone updated" }
        format.turbo_stream { stream_redirect_to return_path }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    account = @milestone.account
    @milestone.destroy
    return_path = params[:return_to].presence || account_path(account)

    respond_to do |format|
      format.html { redirect_to return_path, notice: "Milestone deleted" }
      format.turbo_stream { stream_redirect_to return_path }
    end
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def set_milestone
      @milestone = Milestone.joins(:account).where(accounts: { family: Current.family }).find(params[:id])
    end

    def milestone_params
      params.require(:milestone).permit(:name, :target_amount, :target_date, :target_type, :starting_balance, :target_percentage)
    end

    def stream_redirect_to(url)
      render turbo_stream: turbo_stream.action(:redirect, url)
    end
end
