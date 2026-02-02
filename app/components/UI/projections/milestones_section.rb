# Shared milestone section component for projection cards
class UI::Projections::MilestonesSection < ApplicationComponent
  include Milestoneable

  attr_reader :account, :tab_name, :title, :empty_description

  def initialize(account:, tab_name:, title: "Milestones", empty_description: nil)
    @account = account
    @tab_name = tab_name
    @title = title
    @empty_description = empty_description || default_empty_description
  end

  private

    def default_empty_description
      case tab_name
      when "debt"
        "Track paydown goals like \"Pay off by 2028\" or \"Reduce to $100K\""
      when "investments"
        "Set targets like \"Reach $100K\" or \"Save for down payment\""
      else
        nil
      end
    end
end
