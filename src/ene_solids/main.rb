# Eneroth solid Tools

# Copyright Julia Christina Eneroth, eneroth3@gmail.com

module EneSolidTools

  Sketchup.require(File.join(File.dirname(__FILE__), "solids"))
  Sketchup.require(File.join(File.dirname(__FILE__), "tools"))

  # Internal: Reload whole extension (except loader) without littering
  # console. Inspired by ThomTohm's method.
  #
  # Returns nothing.
  def self.reload

    # Hide warnings for already defined constants.
    old_verbose = $VERBOSE
    $VERBOSE = nil

    # Load
    Dir.glob(File.join(File.dirname(__FILE__), "*.rb")).each { |f| load(f) }

    $VERBOSE = old_verbose

    nil

  end

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    # Only allow menu for SketchUp Pro.
    if Sketchup.is_pro?

      # Menu bar
      menu = UI.menu("Tools").add_submenu("Eneroth Solid Tools")
      menu.add_item("Union") { UnionTool.new.run_or_activate }
      menu.add_item("Subtract") { SubtractTool.new.run_or_activate }
      menu.add_item("Trim") { TrimTool.new.run_or_activate }

      # Toolbar
      tb = UI::Toolbar.new("Eneroth Solid Tools")

      cmd = UI::Command.new("Union") {UnionTool.new.run_or_activate }
      cmd.large_icon = "union.png"
      cmd.small_icon = "union_small.png"
      cmd.tooltip = "Union"
      cmd.status_bar_text = "Add one solid group or component to another."
      tb.add_item cmd

      cmd = UI::Command.new("Subtract") { SubtractTool.new.run_or_activate }
      cmd.large_icon = "subtract.png"
      cmd.small_icon = "subtract_small.png"
      cmd.tooltip = "Subtract"
      cmd.status_bar_text = "Subtract one solid group or component from another."
      tb.add_item cmd

      cmd = UI::Command.new("Trim") { TrimTool.new.run_or_activate }
      cmd.large_icon = "trim.png"
      cmd.small_icon = "trim_small.png"
      cmd.tooltip = "Trim"
      cmd.status_bar_text = "Trim away one solid group or component from another."
      tb.add_item cmd

      UI.start_timer(0.1, false){ tb.restore }#Use timer as workaround for bug 2902434.

    else
      UI.messagebox("Eneroth Solids Tools are for legal reasons only available for SketchUp Pro.")
    end
  end

end
