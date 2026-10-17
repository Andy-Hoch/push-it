module ApplicationHelper
  def avatar_tag(name, classes: nil)
    hue = name.to_s.bytes.sum * 47 % 360
    tag.span(name.to_s.first.upcase, class: [ "avatar", classes ], style: "--hue: #{hue}", aria: { hidden: true })
  end

  def countdown_tag(deadline, classes: nil)
    return unless deadline

    tag.span(class: [ "chip tabular-nums", classes ], data: { controller: "countdown", countdown_deadline_value: deadline.iso8601 }) do
      safe_join([ "⏱", tag.span("", data: { countdown_target: "label" }) ], " ")
    end
  end
end
