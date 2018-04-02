module Eneroth
module SolidTools

  Sketchup.require File.join(PLUGIN_DIR, "vendor", "cmty-lib", "ui")
  Sketchup.require File.join(PLUGIN_DIR, "tools")

  unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    # Extension Warehouse doesn't allow hosting this extension unless it's
    # limited to SketchUp Pro, since it replicates a Pro feature.
    if Sketchup.is_pro?

      menu = UI.menu("Tools").add_submenu(EXTENSION.name)
      item = menu.add_item("Union") { Tools::Union.perform_or_activate }
      menu.set_validation_proc(item) { Tools::Union.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Subtract") { Tools::Subtract.perform_or_activate }
      menu.set_validation_proc(item) { Tools::Subtract.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Trim") { Tools::Trim.perform_or_activate }
      menu.set_validation_proc(item) { Tools::Trim.active? ? MF_CHECKED : MF_UNCHECKED }
      item = menu.add_item("Intersect") { Tools::Intersect.perform_or_activate }
      menu.set_validation_proc(item) { Tools::Intersect.active? ? MF_CHECKED : MF_UNCHECKED }

      tb = UI::Toolbar.new(EXTENSION.name)

      cmd = UI::Command.new("Union") { Tools::Union.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "union#{LUI.icon_file_extension}")
      cmd.tooltip = "Union"
      cmd.status_bar_text = "Unite solid groups/components to larger ones."
      cmd.set_validation_proc { Tools::Union.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Subtract") { Tools::Subtract.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "subtract#{LUI.icon_file_extension}")
      cmd.tooltip = "Subtract"
      cmd.status_bar_text = "Subtract solid groups/components."
      cmd.set_validation_proc { Tools::Subtract.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Trim") { Tools::Trim.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "trim#{LUI.icon_file_extension}")
      cmd.tooltip = "Trim"
      cmd.status_bar_text = "Trim solid groups/components to other solids."
      cmd.set_validation_proc { Tools::Trim.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

      cmd = UI::Command.new("Intersect") { Tools::Intersect.perform_or_activate }
      cmd.large_icon = cmd.small_icon = File.join(PLUGIN_DIR, "images", "intersect#{LUI.icon_file_extension}")
      cmd.tooltip = "Intersect"
      cmd.status_bar_text = "Find overlap between solid groups/components."
      cmd.set_validation_proc { Tools::Intersect.active? ? MF_CHECKED : MF_UNCHECKED }
      tb.add_item cmd

    else
      UI.messagebox("Eneroth Solids Tools in Extension Warehouse is only available for SketchUp Pro.")
    end
  end

end
end
