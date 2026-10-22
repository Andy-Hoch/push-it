card = Gameplay::Card.new(code)

json.code card.code
json.kind card.kind
json.value card.value
json.bonus card.bonus
json.label card.label
