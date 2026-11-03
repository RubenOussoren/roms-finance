# Shared navigation context; this does not authorize account access.
module ProjectionContext
  extend ActiveSupport::Concern

  SUPPORTED_YEARS = [ 5, 10, 20, 30 ].freeze
  DEFAULT_YEARS = 10

  private
    def projection_context(default_tab: "overview")
      tab = params[:tab]
      scope = params[:scope]
      {
        tab: %w[overview investments debts strategies].include?(tab) ? tab : default_tab,
        scope: %w[personal household].include?(scope) ? scope : "household",
        projection_years: supported_projection_years || DEFAULT_YEARS
      }
    end

    def supported_projection_years
      SUPPORTED_YEARS.find { |years| params[:projection_years].to_s == years.to_s }
    end

    def projection_horizon_notice
      return if params[:projection_years].nil? || supported_projection_years

      I18n.t("projections.unsupported_horizon", years: DEFAULT_YEARS)
    end
end
