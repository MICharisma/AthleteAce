require "rails_helper"

RSpec.describe "The standard rating scale" do
  it "accepts the endpoints and neutral zero, while rejecting values outside the range" do
    rating = build(:rating)
    [ -100, 0, 500 ].each do |value|
      rating.value = value
      expect(rating).to be_valid
    end
    [ -101, 501, "1.5", nil ].each do |value|
      rating.value = value
      expect(rating).not_to be_valid
    end
  end

  it "positions zero one sixth of the way from the negative to the positive endpoint" do
    rating = build(:rating, value: -100)
    expect(rating.normalized_value).to eq(0)
    rating.value = 0
    expect(rating.normalized_value).to be_within(0.0001).of(1.0 / 6)
    rating.value = 500
    expect(rating.percentage_value).to eq(100)
  end

  it "positions fractional averages on the same scale" do
    player = create(:player)
    spectrum = create(:spectrum)
    create(:rating, rated: player, spectrum: spectrum, value: 43)
    create(:rating, rated: player, spectrum: spectrum, value: 44)
    expect(player.normalized_average_rating_on(spectrum)).to be_within(0.0001).of(143.5 / 600)
  end

  it "also enforces the range on writes that skip model validation" do
    rating = create(:rating, value: 0)
    expect do
      Rating.transaction(requires_new: true) { rating.update_column(:value, 501) }
    end.to raise_error(ActiveRecord::StatementInvalid, /ratings_value_in_standard_scale/)
    expect(rating.reload.value).to eq(0)
  end
end
