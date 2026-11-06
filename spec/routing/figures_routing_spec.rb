require "rails_helper"

RSpec.describe "Figure routes", type: :routing do
  it "routes public career pages to figures" do
    expect(get: "/figures/12").to route_to("figures#show", id: "12")
    expect(get: "/people/12").not_to be_routable
  end

  it "keeps Admin People on the account controller" do
    expect(get: "/admin/people/12").to route_to("admin/people#show", id: "12")
  end
end
