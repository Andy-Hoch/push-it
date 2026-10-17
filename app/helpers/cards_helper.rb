module CardsHelper
  ACTION_ICONS = { "freeze" => "❄", "flip3" => "3", "chance" => "♥" }.freeze

  def card_tag(code, size: :md, flag: nil, uid: nil, style: nil)
    card = code.is_a?(Gameplay::Card) ? code : Gameplay::Card.new(code)
    classes = [ "card", "card-#{size}", ("card-modifier" if card.modifier?), ("card-action card-#{card.code}" if card.action?),
                ("is-bust" if flag == "bust"), ("is-held" if flag == "held") ]
    ink = card.number? ? "--ink: var(--color-n#{card.value});" : ""

    tag.div(id: uid && "card-#{uid}", class: classes, style: "#{ink}#{style}", title: card.label, aria: { label: card.label }) do
      if card.action?
        safe_join([ tag.span(ACTION_ICONS[card.code], class: "card__value"), tag.span(card.label, class: "card__title") ])
      else
        safe_join([ tag.span(card.label, class: "card__corner card__corner--tl"), tag.span(card.label, class: "card__value"),
                    tag.span(card.label, class: "card__corner card__corner--br") ])
      end
    end
  end

  def hand_entry_tag(entry, size: :md)
    card_tag(entry["code"], size: size, flag: entry["flag"], uid: entry["uid"])
  end
end
