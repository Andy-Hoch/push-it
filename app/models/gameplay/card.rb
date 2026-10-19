# A single card, encoded as a short string so game state stays plain JSON:
# "n0".."n12" number cards, "m+2".."m+10" and "mx2" score modifiers,
# "freeze", "triple" and "chance" (Second Chance) action cards.
class Gameplay::Card
  ACTIONS = %w[ freeze triple chance ].freeze
  MODIFIERS = %w[ m+2 m+4 m+6 m+8 m+10 mx2 ].freeze

  attr_reader :code

  def initialize(code)
    @code = code.to_s
  end

  def number?
    code.match?(/\An\d{1,2}\z/)
  end

  def modifier?
    MODIFIERS.include?(code)
  end

  def action?
    ACTIONS.include?(code)
  end

  def multiplier?
    code == "mx2"
  end

  def freeze?
    code == "freeze"
  end

  def triple?
    code == "triple"
  end

  def second_chance?
    code == "chance"
  end

  def value
    number? ? code.delete_prefix("n").to_i : nil
  end

  def bonus
    modifier? && !multiplier? ? code.delete_prefix("m+").to_i : 0
  end

  def kind
    if number? then :number
    elsif modifier? then :modifier
    else :action
    end
  end

  def label
    if number? then value.to_s
    elsif multiplier? then "×2"
    elsif modifier? then "+#{bonus}"
    else I18n.t("gameplay.cards.#{code}")
    end
  end

  def ==(other)
    other.is_a?(self.class) && other.code == code
  end
  alias eql? ==

  def hash
    code.hash
  end
end
