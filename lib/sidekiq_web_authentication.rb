require "digest"
require "active_support/core_ext/object/blank"
require "active_support/security_utils"

class SidekiqWebAuthentication
  def self.authenticated?(username, password, configured_username:, configured_password:)
    return false if configured_username.blank? || configured_password.blank? || configured_password == "roms"
    return false if username.blank? || password.blank?

    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(configured_username)) &&
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(configured_password))
  end
end
