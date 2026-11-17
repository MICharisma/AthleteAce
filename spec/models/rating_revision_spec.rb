require "rails_helper"

RSpec.describe RatingRevision do
  let(:ace) { create(:ace) }
  let(:player) { create(:player) }
  let(:spectrum) { create(:spectrum) }

  def replace value, notes: nil
    RatingService.replace ace: ace, target: player, spectrum_id: spectrum.id, value: value, notes: notes
  end

  it "keeps set, archive and removal events separate from the current rating" do
    original = replace 100, notes: "First impression"
    current = replace 300, notes: "After another game"
    expect { replace 300, notes: "After another game" }.not_to change(RatingRevision, :count)
    current.destroy!

    revisions = ace.rating_revisions.order(:id)
    expect(revisions.pluck(:operation, :value, :archived)).to eq([
      [ "set", 100, false ], [ "archive", 100, true ], [ "set", 300, false ], [ "remove", 300, false ]
    ])
    expect(revisions.last).to have_attributes rating_id: current.id, target_type: "Player", target_id: player.id,
      spectrum_id: spectrum.id, notes: "After another game"
    expect(original.reload).to be_archived
    expect(ace.ratings.active).to be_empty
  end

  it "keeps the dimension as it was when the opinion was recorded" do
    replace 0
    definition = spectrum.rating_dimension.to_h.stringify_keys
    spectrum.update! description: "A revised question", low_label: "Another low label"

    expect(ace.rating_revisions.sole.dimension).to eq(definition)
    expect(ace.rating_revisions.sole.value).to eq(0)
  end

  it "records direct edits and ignores saves that do not change the opinion" do
    rating = replace 100
    rating.update! value: 200, notes: "Updated"
    expect { rating.touch }.not_to change(RatingRevision, :count)
    expect { rating.update value: 99_999 }.not_to change(RatingRevision, :count)
    expect(ace.rating_revisions.order(:id).pluck(:value)).to eq([ 100, 200 ])
  end

  it "rolls back history and the opinion together" do
    rating = replace 100
    expect do
      Rating.transaction do
        rating.update! value: 200
        raise ActiveRecord::Rollback
      end
    end.not_to change(RatingRevision, :count)
    expect(rating.reload.value).to eq(100)
  end

  it "retains history after the rated profile and spectrum are removed" do
    replace 100
    player.destroy!
    spectrum.destroy!
    expect(ace.rating_revisions.order(:id).pluck(:operation)).to eq([ "set", "remove" ])
    expect(ace.rating_revisions.first.target_id).to eq(player.id)
  end

  it "removes personal history when the owning account is deleted" do
    replace 100
    ace.destroy!
    expect(RatingRevision.where(ace_id: ace.id)).to be_empty
  end
end
