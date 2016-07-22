#Eneroth solid Tools

#Coded because I needed them in another plugin.

#Differences from official solid tools:
#  Preserves original group/component with its material, layer, attributes etc.
#  Preserves raw geometry inside groups/components with its layer, attributes etc.
#  Ignores nested geometry, a house is for instance still a solid you can cut away a part of even if there's a cut-opening window component in the wall.
#  Operations on components alters all instances as expected.

#Free to use plugin for commercial or non-commercial modeling.
#Add Solids class in your own code to include these methods.
#Free to use code in non-commercial plugins as long as I, Julia Christina Eneroth (Eneroth3), am credited if plugin is published.
#For commercial plugins, contact me and we'll find a solution that makes us both happy :) .
#NOTE: Find a proper license that says ^this and include it.

module Ene_SolidTools

class Solids

  # Public: Check if a group or component is solid. If every edge binds two faces
  # group/component counts as solid. Nested groups and components are ignored.
  #
  # group_or_component - The group or component to test.
  #
  # Returns true if solid, false if not and nil if not a group or component.
  def self.is_solid?(group_or_component)

    return unless [Sketchup::Group, Sketchup::ComponentInstance].any? { |c| group_or_component.is_a? c}
    ents = entities_from_group_or_componet group_or_component

    !ents.any? { |e| e.is_a?(Sketchup::Edge) && e.faces.length != 2 }

  end

  # Public: Check whether point is inside, outside or on face of solid.
  #
  # point                     - Point to test (global coordinates).
  # group_or_component        - Group or component to test.
  # return_value_when_on_face - What to return when point is on face of solid.
  #                             (default: true)
  #
  # Returns true if point is inside group, false if outside and
  #   return_value_when_on_face when point is on face.
  #   Returns nil if group_or_component isn't a solid.
  def self.inside_solid?(point, group_or_component, return_value_when_on_face = true)

    return unless self.is_solid? group_or_component

    #Cast a ray from point in random direction an check how many times it intersects the mesh.
    #Odd number means it's inside mesh, even means it's outside of it.

    #Transform point to local coordinates of this group/component.
    #These coordinates are used in the API no matter current drawing context,
    #EXCEPT when the drawing context is inside this group/component.
    #This oddity seems to be undocumented but as long as the user isn't inside
    #this group/component everything should be just fine (I hope).
    #More info: http://forums.sketchup.com/t/what-is-coordinates-relative-to/3102
    point = point.clone
    point.transform! group_or_component.transformation.inverse

    vector = Geom::Vector3d.new 234, 1343, 345#NOTE: using random vector makes code work in most cases. why didn't x axis work? did ray hit between 2 faces at once counting them as 2? Did it count a tangential face?
    line = [point, vector]
    intersections = []
    ents = entities_from_group_or_componet group_or_component

    ents.each do |f|
      next unless f.is_a?(Sketchup::Face)
      plane = f.plane

      #If point is on face of solid, return given value.
      clasify_point = f.classify_point point
      return return_value_when_on_face if [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include? clasify_point

      #Don't count face if ray tangents it.
      next if point.on_plane?(f.plane) && point.offset(vector).on_plane?(f.plane)

      intersection = Geom.intersect_line_plane line, plane
      next unless intersection
      next if intersection == point

      #Check if intersection is in the direction ray is casted.
      next unless (intersection - point).samedirection? vector

      #Check intersection's relation to face.
      #Counts as intersection if on face, including where cut-opening component cuts it.
      classify_intersection = f.classify_point intersection
      next unless classify_intersection == Sketchup::Face::PointInside

      #Remember intersection so intersections can be counted.
      #Save intersection as array so duplicated intersections fro where ray meets edge between faces can be removed and counted as one.
      intersections << intersection.to_a
    end

    #If ray hits an edge 2 faces have intersections for the same point.
    #Only counts as hitting the mesh once though.
    #NOTE: LOGIC FAIL: duplicated point could both mean ray enters/leaves solid through an edge, but also that ray tangents an edge of the solid :O .
    intersections.uniq!

    #Return
    intersections.length.odd?

  end

  # Public: Unite one solid group/component to another.
  #
  # The original group/component keeps its material, layer, attributes etc.
  # Raw geometry inside both groups/components keep their material layer
  # attributes etc.
  #
  # original - The original group/component.
  # to_add   - The group/component to add to the original.
  #
  # Returns nothing.
  def self.union(original, to_add)#NOTE: optional wrap-in-operator argument.

    #Check if both groups/components are solid.
    return if !is_solid?(original) || !is_solid?(to_add)
    
    #Make groups unique so no other instances of are altered.
    #Group.make_unique is for some reason deprecated, change name instead.
    original.name += "" if original.is_a? Sketchup::Group
    to_add.name += "" if to_add.is_a? Sketchup::Group
    
    original_ents = entities_from_group_or_componet original
    to_add_ents = entities_from_group_or_componet to_add

    #Double intersect so intersection edges appear in both contexts.
    #NOTE: NICER CODE: make double_intersect its own methods?
    #NOTE: groups/components must be in the same drawing context for these transformations to work.
    original_ents.intersect_with false, original.transformation, to_add_ents, to_add.transformation, true, to_add
    to_add_ents.intersect_with false, to_add.transformation, original_ents, original.transformation, true, original

    #Remove edges that are inside the solid of the other group.
    to_remove = find_ents_to_remove original, to_add, true, false
    to_remove1 = find_ents_to_remove to_add, original, true, false
    original_ents.erase_entities to_remove
    to_add_ents.erase_entities to_remove1
    
    #Paste-in-placea to_add, exploda
    #...

    #Check if still solid.
    #...
    #Return true if still solid, otherwise false? try to fill gaps?

    nil

  end

  # Public: Subtract one solid group/component from another.
  #
  # The original group/component keeps its material, layer, attributes etc.
  # Raw geometry inside both groups/components keep their material layer
  # attributes etc.
  #
  # original    - The original group/component.
  # to_subtract - The group/component to subtract from the original.
  #
  # Returns nothing.
  def self.subtract(original, to_subtract)

    #NOT: code
puts "Subtract code not yet written"
    nil

  end

  #NOTE: make private/protected. document.
  def self.entities_from_group_or_componet(group_or_component)

    return group_or_component.entities if group_or_component.is_a?(Sketchup::Group)
    group_or_component.definition.entities

  end

  def self.find_ents_to_remove(to_remove_in, refernce, inside, on_surface)
  
    to_remove_in_ents = entities_from_group_or_componet to_remove_in    
    to_erase = []
    to_remove_in_ents.each do |e|
      next unless e.is_a? Sketchup::Edge
      midpoint = Geom.linear_combination 0.5, e.start.position, 0.5, e.end.position
      midpoint.transform! to_remove_in.transformation
      next unless inside_solid? midpoint, refernce, false#NOTE: adapt to remove inside, outside, on surface
      to_erase << e
    end
    
    to_erase
    
  end
  
end#class

class BaseTool

  def activate

    #If 2 solids and nothing else is selected, perform operation on those.
    #Otherwise let user click them one at a time and also define which one is
    #one for asymmetrical operations.
    mod = Sketchup.active_model
    sel = mod.selection
    if sel.length == 2 && sel.all? { |e| Solids.is_solid? e }

      ent0 = sel[0]#NOTE: sort after bounding box volume
      ent1 = sel[1]
      Solids.send @method_name, ent0, ent1

      #Go back to previous tool to make this tool feel like an operator
      #triggered directly from the menu rather than an actual tool.
      mod.tools.pop_tool#NOTE: this and status text doesn't work properly. run this code without even activating tool instead of somehow de-activate it!

      #Tell user operations has been done.
      #Tell user to activate tool without a selection to chose order of
      #groups/components if operation was asymmetrical.
      Sketchup.status_text = @statusbar_run_at_activate

    else

      #Do normal tool initialize stuff here since the initialize method is
      #written in the separate classes that inherits from this one.
      @ph = Sketchup.active_model.active_view.pick_helper
      @cursor = UI.create_cursor(File.join(PLUGIN_ROOT, "ene_solids", @cursor_path), 2, 2)
      self.reset

    end

  end

  def onSetCursor

    UI.set_cursor @cursor

  end#def

  def onMouseMove(flags, x, y, view)

    #Highlight hovered solid by making it the only selected entity.
    #Consistent to rotation, move and scale tool.
    mod = Sketchup.active_model
    sel = mod.selection
    sel.clear#! Sketchup API, I'm disappointed at you :(

    @ph.do_pick(x, y)
    picked = @ph.best_picked
    return if picked == @ent0
    sel.add picked if Solids.is_solid? picked

  end

  def onLButtonDown(flags, x, y, view)

    #Get what was clicked, return if not a solid.
    @ph.do_pick(x, y)
    picked = @ph.best_picked
    return unless Solids.is_solid? picked

    if !@ent0
      #Select first group or component
      Sketchup.status_text = @statusbar1
      @ent0 = picked
    else
      #Select second group or component and run operator if first one is already selected.
      return if picked == @ent0
      ent0 = @ent0
      ent1 = picked
      Solids.send @method_name, ent0, ent1
      self.reset#NOTE: say "Done." in statusbar?
    end

  end

  def resume(view)

    Sketchup.status_text = !@ent0 ? @statusbar : @statusbar1

  end

  def onCancel(reason, view)

    self.reset

  end

  def reset

    Sketchup.status_text = @statusbar
    @ent0 = nil

  end

end#class

class UnionTool < BaseTool

  def initialize

    @cursor_path = "cursor_union.png"
    @statusbar = "Click original solid group/component to add to."
    @statusbar1 = "Click other solid group/component to add."
    @statusbar_run_at_activate = "Done."
    @method_name = :union

  end

end#class

class SubtractTool < BaseTool

  def initialize

    @cursor_path = "cursor_subtract.png"
    @statusbar = "Click original solid group/component to subtract from."
    @statusbar1 = "Click other solid group/component to subtract."
    @statusbar_run_at_activate = "Done. By instead activating tool without a selection you can chose what to subtract from what."
    @method_name = :subtract

  end

end#class

#Menus and toolbars
file = __FILE__
unless file_loaded? file

  #Menu bar
  menu = UI.menu("Tools").add_submenu("Eneroth Solid Tools")
  menu.add_item("Union") { Sketchup.active_model.select_tool UnionTool.new }
  menu.add_item("Subtract") { Sketchup.active_model.select_tool SubtractTool.new }

  #Toolbar
  tb = UI::Toolbar.new("Eneroth Solid Tools")

  cmd = UI::Command.new("Union") { Sketchup.active_model.select_tool UnionTool.new }
  cmd.large_icon = "union.png"
  cmd.small_icon = "union_small.png"
  cmd.tooltip = "Union"
  cmd.status_bar_text = "Add one solid group or component to another."
  tb.add_item cmd

  cmd = UI::Command.new("Subtract") { Sketchup.active_model.select_tool SubtractTool.new }
  cmd.large_icon = "subtract.png"
  cmd.small_icon = "subtract_small.png"
  cmd.tooltip = "Subtract"
  cmd.status_bar_text = "Subtract one solid group or component from another."
  tb.add_item cmd

  UI.start_timer(0.1, false){ tb.restore }#Use timer as workaround for bug 2902434.

  file_loaded file

end

end#module
