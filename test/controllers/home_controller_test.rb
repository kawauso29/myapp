require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root redirects to admin" do
    get root_url
    assert_redirected_to admin_root_path
  end
end
