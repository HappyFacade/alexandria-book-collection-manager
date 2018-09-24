# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class AlertDialog < SimpleDelegator
      def initialize(parent, title, stock_icon, buttons, message = nil)
        dialog = Gtk::Dialog.new
        dialog.title = ""
        dialog.destroy_with_parent = true
        dialog.parent = parent
        buttons.each do |button_text, response_id|
          dialog.add_button button_text, response_id
        end
        super(dialog)

        dialog.border_width = 6
        dialog.resizable = false
        dialog.content_area.spacing = 12

        hbox = Gtk::Box.new(:horizontal, 12)
        hbox.homogeneous = false
        hbox.border_width = 6
        dialog.content_area.pack_start(hbox, false, false, 0)

        image = Gtk::Image.new_from_icon_name(stock_icon, :dialog)
        image.set_alignment(0.5, 0)
        hbox.pack_start(image, false, false, 0)

        vbox = Gtk::Box.new(:vertical, 6)
        vbox.homogeneous = false
        hbox.pack_start(vbox, false, false, 0)

        vbox.pack_start(make_label("<b><big>#{title}</big></b>"), false, false, 0)
        vbox.pack_start(make_label(message.strip), false, false, 0) unless message
      end

      def make_label(markup)
        label = Gtk::Label.new
        label.set_alignment(0, 0)
        label.wrap = label.selectable = true
        label.markup = markup
        label
      end
    end
  end
end
