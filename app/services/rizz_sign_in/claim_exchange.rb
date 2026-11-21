module RizzSignIn
  # Server-to-server step of a claim: spend the browser's receipt and bind the Ace to the Rizz subject.
  # Repeating an operation_id for the same subject returns the same success.
  class ClaimExchange
    Result = Struct.new(:status, :ace)

    def self.call(**args)
      new(**args).call
    end

    def initialize(operation_id:, receipt:, rizz_sub:, rizz_session_epoch:)
      @operation_id, @receipt, @rizz_sub, @epoch = operation_id, receipt, rizz_sub, rizz_session_epoch
    end

    # status: :ok, :invalid (bad or spent receipt), :conflict (already bound elsewhere)
    def call
      ApplicationRecord.transaction { bind }
    rescue ActiveRecord::RecordNotUnique
      replay || Result.new(:conflict)
    end

    private

    def bind
      return replay if AceRizzBinding.exists?(operation_id: @operation_id)

      receipt = RizzClaimReceipt.find_by_receipt(@receipt)
      return Result.new(:invalid) unless receipt&.usable? && receipt.operation_id == @operation_id

      ace = receipt.ace
      return Result.new(:invalid) if ace.suspended? || !ace.confirmed?

      by_sub = AceRizzBinding.lock.find_by(rizz_sub: @rizz_sub)
      held = AceRizzBinding.lock.active.find_by(ace_id: ace.id)
      return Result.new(:conflict) if (held && held.rizz_sub != @rizz_sub) || (by_sub&.active? && by_sub.ace_id != ace.id)
      return Result.new(:invalid) unless receipt.consume!

      attributes = { ace: ace, operation_id: @operation_id, status: "active", connected_at: Time.current, disconnected_at: nil }
      if by_sub
        by_sub.update!(attributes.merge(rizz_session_epoch: [ by_sub.rizz_session_epoch, @epoch ].max))
      else
        AceRizzBinding.create!(attributes.merge(rizz_sub: @rizz_sub, rizz_session_epoch: @epoch))
      end
      Result.new(:ok, ace)
    end

    def replay
      binding = AceRizzBinding.active.find_by(operation_id: @operation_id)
      binding&.rizz_sub == @rizz_sub ? Result.new(:ok, binding.ace) : Result.new(:conflict)
    end
  end
end
