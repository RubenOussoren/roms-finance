require "test_helper"

class MoneyFieldTest < ActionView::TestCase
  [ "", "0", "-125.2500" ].each do |value|
    test "raw amount override retains #{value.inspect}" do
      render_money_field(raw_value: value)
      assert_dom "input[name='entry[amount]']" do |inputs|
        assert_equal value, inputs.first["value"].to_s
      end
    end
  end

  test "raw amount override escapes attribute content" do
    value = %q{125"/><script>alert(1)</script>}
    render_money_field(raw_value: value)
    assert_dom "input[name='entry[amount]']" do |inputs|
      assert_equal value, inputs.first["value"]
    end
    assert_dom "script", count: 0
  end

  test "ordinary money fields still use currency precision" do
    render_money_field
    assert_dom "input[name='entry[amount]'][value='12.30']"
  end

  private
    def render_money_field(**options)
      entry = Entry.new(amount: 12.3, currency: "USD")
      render inline: '<%= styled_form_with model: entry, url: "/" do |f| %><%= f.money_field :amount, **options %><% end %>',
        locals: { entry:, options: }
    end
end
