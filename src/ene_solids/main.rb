module Eneroth
module SolidTools

  if Sketchup.version.to_i < REQUIRED_SU_VERSION
    msg = "#{EXTENSION.name} requires SketchUp 20#{REQUIRED_SU_VERSION} or later to run."
    UI.messagebox(msg)
    raise msg
  end

  Sketchup.require(File.join(PLUGIN_DIR, "solids"))
  Sketchup.require(File.join(PLUGIN_DIR, "tools"))

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

    Dir.glob(File.join(PLUGIN_DIR, "*.rb")).each { |f| load(f) }
    $VERBOSE = verbose

    # Use a timer to make call to method itself register to console.
    # Otherwise the user cannot use up arrow to repeat command.
    UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

    Sketchup.undo if undo_last

    nil
  end

  def self.tb_extension
    if Sketchup.version.to_i < 16
      "png"
    elsif Sketchup.platform == :platform_win
      "svg"
    else
      "pdf"
    end
  end

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    # Extension Warehouse doesn't allow hosting this extension unless it's
    # limited to SketchUp Pro since it replicates a Pro feature.
    if Sketchup.is_pro?

      menu = UI.menu("Tools").add_submenu(EXTENSION.name)
      item = menu.add_item("Union") { UnionTool.perform_or_activate }
      menu.set_validation_proc(item) { UnionTool.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Subtract") { SubtractTool.perform_or_activate }
      menu.set_validation_proc(item) { SubtractTool.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Trim") { TrimTool.perform_or_activate }
      menu.set_validation_proc(item) { TrimTool.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Intersect") { IntersectTool.perform_or_activate }
      menu.set_validation_proc(item) { IntersectTool.active? ? MF_CHECKED : MF_UNCHECKED }

      tb = UI::Toolbar.new(EXTENSION.name)

      cmd = UI::Command.new("Union") {UnionTool.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "union.#{tb_extension}")
      cmd.tooltip = "Union"
      cmd.status_bar_text = "Add one solid group or component to another."
      cmd.set_validation_proc { UnionTool.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Subtract") { SubtractTool.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "subtract.#{tb_extension}")
      cmd.tooltip = "Subtract"
      cmd.status_bar_text = "Subtract one solid group or component from another."
      cmd.set_validation_proc { SubtractTool.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Trim") { TrimTool.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "trim.#{tb_extension}")
      cmd.tooltip = "Trim"
      cmd.status_bar_text = "Trim away one solid group or component from another."
      cmd.set_validation_proc { TrimTool.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Intersect") { IntersectTool.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "intersect.#{tb_extension}")
      cmd.tooltip = "Intersect"
      cmd.status_bar_text = "Find intersection between solid groups or components."
      cmd.set_validation_proc { IntersectTool.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

    else
      UI.messagebox("Eneroth Solids Tools in Extension Warehouse is only available for SketchUp Pro.")
    end
  end

end
end
