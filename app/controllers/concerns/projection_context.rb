# Shared navigation context; this does not authorize account access.
module ProjectionContext
  extend ActiveSupport::Concern

  private
    def projection_context(default_tab: "overview")
      tab = params[:tab]
      scope = params[:scope]
      years = params[:projection_years].to_s
      {
        tab: %w[overview investments debts strategies].include?(tab) ? tab : default_tab,
        scope: %w[personal household].include?(scope) ? scope : "household",
        projection_years: years.match?(/\A[0-9]+\z/) && years.to_i.positive? ? years.to_i : 10
      }
    end
end
