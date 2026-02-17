require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_url
    assert_response :success
  end

  test "create redirects to correct URL" do
    post registration_url, params: { user: {
      email: "john@example.com",
      password: "Password1!" } }

    assert_redirected_to root_url
  end

  test "create when hosted requires an invite code" do
    with_env_overrides REQUIRE_INVITE_CODE: "true" do
      # Without invite code, redirected to login (registration is gated)
      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!" } }
        assert_redirected_to new_session_url

        # Invalid invite code is rejected at the gate
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: "foo" } }
        assert_redirected_to new_session_url
      end

      assert_difference "User.count", +1 do
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!",
          invite_code: InviteCode.generate! } }
        assert_redirected_to root_url
      end
    end
  end

  test "blocked without invitation when invite-only is on" do
    with_self_hosting do
      Setting.require_invite_for_signup = true

      get new_registration_url
      assert_redirected_to new_session_url
      assert_equal "Registration is by invitation only.", flash[:alert]

      assert_no_difference "User.count" do
        post registration_url, params: { user: {
          email: "john@example.com",
          password: "Password1!" } }
      end
      assert_redirected_to new_session_url
    ensure
      Setting.require_invite_for_signup = false
    end
  end

  test "first user can register when invite-only is on" do
    with_self_hosting do
      Setting.require_invite_for_signup = true

      User.stubs(:count).returns(0)

      get new_registration_url
      assert_response :success
    ensure
      Setting.require_invite_for_signup = false
    end
  end

  test "invitation token bypasses invite-only gate" do
    with_self_hosting do
      Setting.require_invite_for_signup = true

      invitation = invitations(:one)

      get new_registration_url, params: { invitation: invitation.token }
      assert_response :success
    ensure
      Setting.require_invite_for_signup = false
    end
  end

  test "valid invite code in URL allows access to form" do
    with_self_hosting do
      Setting.require_invite_for_signup = true
      token = InviteCode.generate!

      get new_registration_url, params: { invite: token }
      assert_response :success

      # Code should NOT be consumed by the GET (only POST claims it)
      assert InviteCode.exists?(token: token), "invite code should not be consumed by GET"
    ensure
      Setting.require_invite_for_signup = false
    end
  end

  test "invalid invite code in URL is rejected" do
    with_self_hosting do
      Setting.require_invite_for_signup = true

      get new_registration_url, params: { invite: "bogus" }
      assert_redirected_to new_session_url
    ensure
      Setting.require_invite_for_signup = false
    end
  end
end
