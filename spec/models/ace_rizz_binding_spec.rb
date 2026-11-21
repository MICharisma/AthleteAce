require "rails_helper"

RSpec.describe AceRizzBinding, type: :model do
  let(:ace) { create(:ace) }

  def bind(ace: self.ace, sub: "sub-#{SecureRandom.hex(4)}", operation: "op-#{SecureRandom.hex(4)}", **attributes)
    described_class.create!(ace: ace, rizz_sub: sub, operation_id: operation, **attributes)
  end

  it "gets a UUIDv7 id and starts active at epoch 1" do
    binding = bind
    expect(binding.id).to match(/\A\h{8}-\h{4}-7\h{3}-[89ab]\h{3}-\h{12}\z/)
    expect(binding).to have_attributes(status: "active", rizz_session_epoch: 1)
    expect(ace.reload.active_rizz_binding).to eq(binding)
    expect(ace.rizz_bindings).to contain_exactly(binding)
  end

  it "allows only one active binding per Ace but any number of disconnected ones" do
    bind
    expect { bind }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { bind(status: "disconnected") }.not_to raise_error
    expect { bind(status: "disconnected") }.not_to raise_error
  end

  it "keeps rizz_sub and operation_id unique" do
    bind(sub: "same")
    expect { bind(ace: create(:ace), sub: "same") }.to raise_error(ActiveRecord::RecordNotUnique)
    first = described_class.last
    expect { bind(ace: create(:ace), operation: first.operation_id) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects an unknown status" do
    expect { bind(status: "pending") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { described_class.new(ace: ace, rizz_sub: "x", operation_id: "y", status: "active").tap { it.status = "bogus" }.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
