class EquityCompensationsController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(:id)
end
