require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  RECORD_SCROLL = <<~JS
    window.scrollSamples = [];
    (function sample() {
      window.scrollSamples.push(Math.round(scrollY));
      if (window.scrollSamples.length < 120) requestAnimationFrame(sample);
    })();
  JS

  test "the rules link glides to the rules section" do
    visit root_path
    execute_script(RECORD_SCROLL)
    click_on I18n.t("home.show.rules_link")
    sleep 1.5

    assert_equal "#regeln", evaluate_script("location.hash")
    assert_in_delta 24, evaluate_script("document.getElementById('regeln').getBoundingClientRect().top"), 8

    samples = evaluate_script("window.scrollSamples")
    final = samples.max
    assert samples.any? { |y| y.positive? && y < final }, "scrolling should pass through intermediate positions, got #{samples.uniq.inspect}"
  end
end
