class MilestonesController < ApplicationController
  before_action :set_account, only: %i[index new create]
  before_action :set_milestone, only: %i[edit update destroy]

  def index
    @milestones = @account.milestones.ordered_by_target
  end

  def new
    @milestone = @account.milestones.new(
      currency: @account.currency,
      status: "pending"
    )
  end

  def edit
    @account = @milestone.account
  end

  def create
    @milestone = @account.milestones.new(milestone_params)
    @milestone.currency ||= @account.currency
    @milestone.is_custom = true
    @milestone.status = "pending"

    if @milestone.save
      @milestone.update_progress!(@account.balance)

      respond_to do |format|
        format.html { redirect_to account_path(@account), notice: "Milestone created" }
        format.turbo_stream { stream_redirect_to account_path(@account) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @milestone.update(milestone_params)
      @milestone.update_progress!(@milestone.account.balance)

      respond_to do |format|
        format.html { redirect_to account_path(@milestone.account), notice: "Milestone updated" }
        format.turbo_stream { stream_redirect_to account_path(@milestone.account) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    account = @milestone.account
    @milestone.destroy

    respond_to do |format|
      format.html { redirect_to account_path(account), notice: "Milestone deleted" }
      format.turbo_stream { stream_redirect_to account_path(account) }
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
      params.require(:milestone).permit(:name, :target_amount, :target_date)
    end

    def stream_redirect_to(url)
      render turbo_stream: turbo_stream.action(:redirect, url)
    end
end
