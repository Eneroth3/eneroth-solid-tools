# Eneroth solid Tools

# Copyright Julia Christina Eneroth, eneroth3@gmail.com

module EneSolidTools

  Sketchup.require(File.join(EXTENSION_DIR, "solids"))
  Sketchup.require(File.join(EXTENSION_DIR, "tools"))

  # Reload whole extension (except loader) without littering
  # console. Inspired by ThomTohm's method.
  # Only works before extension has been scrambled.
  #
  # clear_console - Clear console from previous content too (default: false)
  # undo_last     - Undo last operation in model (default: false).
  #
  # Returns nothing.
  def self.reload(clear_console = false, undo_last = false)

    # Hide warnings for already defined constants.
    verbose = $VERBOSE
    $VERBOSE = nil

    Dir.glob(File.join(EXTENSION_DIR, "*.rb")).each { |f| load(f) }
    $VERBOSE = verbose

    # Use a timer to make call to method itself register to console.
    # Otherwise the user cannot use up arrow to repeat command.
    UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

    Sketchup.undo if undo_last

    nil
  end

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    # Extension Warehouse doesn't allow hosting this extension unless it's
    # limited to SketchUp Pro since it replicates a Pro feature.
    if Sketchup.is_pro?

      menu = UI.menu("Tools").add_submenu(EXTENSION.name)
      menu.add_item("Union") { UnionTool.perform_or_activate }
      menu.add_item("Subtract") { SubtractTool.perform_or_activate }
      menu.add_item("Trim") { TrimTool.perform_or_activate }
      menu.add_item("Intersect") { IntersectTool.perform_or_activate }

      tb = UI::Toolbar.new(EXTENSION.name)

      cmd = UI::Command.new("Union") {UnionTool.perform_or_activate }
      cmd.large_icon = "union.png"
      cmd.small_icon = "union_small.png"
      cmd.tooltip = "Union"
      cmd.status_bar_text = "Add one solid group or component to another."
      tb.add_item cmd

      cmd = UI::Command.new("Subtract") { SubtractTool.perform_or_activate }
      cmd.large_icon = "subtract.png"
      cmd.small_icon = "subtract_small.png"
      cmd.tooltip = "Subtract"
      cmd.status_bar_text = "Subtract one solid group or component from another."
      tb.add_item cmd

      cmd = UI::Command.new("Trim") { TrimTool.perform_or_activate }
      cmd.large_icon = "trim.png"
      cmd.small_icon = "trim_small.png"
      cmd.tooltip = "Trim"
      cmd.status_bar_text = "Trim away one solid group or component from another."
      tb.add_item cmd

      cmd = UI::Command.new("Intersect") { IntersectTool.perform_or_activate }
      cmd.large_icon = "intersect.png"
      cmd.small_icon = "intersect_small.png"
      cmd.tooltip = "Intersect"
      cmd.status_bar_text = "Find intersection between solid groups or components."
      tb.add_item cmd

      UI.start_timer(0.1, false){ tb.restore }#Use timer as workaround for bug 2902434.

    else
      UI.messagebox("Eneroth Solids Tools in Extension Warehouse is available for SketchUp Pro.")
    end
  end

end
