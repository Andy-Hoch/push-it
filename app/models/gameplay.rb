# Pure-Ruby rules of Flip 7. Nothing in here touches the database.
module Gameplay
  class IllegalMove < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(I18n.t("gameplay.errors.#{reason}", default: reason.to_s))
    end
  end
end
