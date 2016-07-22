#Eneroth solid Tools

#Coded because I needed them in another plugin.

#Differences from official solid tools:
#  Preserves original group/component with its material, layer, attributes etc.
#  Preserves raw geometry inside groups/components with its layer, attributes etc.
#  Ignores nested geometry, a house is for instance still a solid you can cut away a part of even if there's a cut-opening window component in the wall.
#  Operations on components alters all instances as expected.
#  Doesn't break material inheritance. If a group/component itself is painted faces wont be painted in its material.

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

    #Use somewhat random vector to reduce risk of ray touching solid without
    #penetrating it.
    vector = Geom::Vector3d.new 234, 1343, 345
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
      next unless [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include? classify_intersection

      #Remember intersection so intersections can be counted.
      #Save intersection as array so duplicated intersections fro where ray meets edge between faces can be removed and counted as one.
      intersections << intersection.to_a
    end

    #If ray hits an edge 2 faces have intersections for the same point.
    #Only counts as hitting the mesh once though.
    #Duplicated point could both mean ray enters/leaves solid through an edge, but also that ray tangents an edge of the solid.
    #Use a quite random ray direction to heavily decrease the risk of ray touch solid.
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
  # Returns true if result is a solid, false if something went wrong.
  def self.union(original, to_add, wrap_in_operator = true)

    #Check if both groups/components are solid.
    return if !is_solid?(original) || !is_solid?(to_add)

    original.model.start_operation "Union", true if wrap_in_operator

    #Make groups unique so no other instances of are altered.
    #Group.make_unique is for some reason deprecated, change name instead.
    original.name += "" if original.is_a? Sketchup::Group
    to_add.name += "" if to_add.is_a? Sketchup::Group

    original_ents = entities_from_group_or_componet original
    to_add_ents = entities_from_group_or_componet to_add
    
    old_coplanar = find_coplanar_edges original_ents
    old_coplanar += find_coplanar_edges to_add_ents

    #Double intersect so intersection edges appear in both contexts.
    double_intersect original, to_add

    #Remove edges that are inside the solid of the other group.
    to_remove = find_ents_to_remove original, to_add, true, false
    to_remove1 = find_ents_to_remove to_add, original, true, false
    original_ents.erase_entities to_remove
    to_add_ents.erase_entities to_remove1

    #Move to_add into original_ents and explode it.
    move_into original, to_add

    #Remove co-planar edges that occurred from the intersection (not those that already existed)
    all_coplanar = find_coplanar_edges original_ents  
    new_coplanar = all_coplanar - old_coplanar
    original_ents.erase_entities new_coplanar

    original.model.commit_operation if wrap_in_operator

    #Return whether result is solid or not
    is_solid? original

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
  # Returns true if result is a solid, false if something went wrong.
  def self.subtract(original, to_subtract, wrap_in_operator = true)

    #Check if both groups/components are solid.
    return if !is_solid?(original) || !is_solid?(to_subtract)

    original.model.start_operation "Subtract", true if wrap_in_operator

    #Make groups unique so no other instances of are altered.
    #Group.make_unique is for some reason deprecated, change name instead.
    original.name += "" if original.is_a? Sketchup::Group
    to_subtract.name += "" if to_subtract.is_a? Sketchup::Group

    original_ents = entities_from_group_or_componet original
    to_subtract_ents = entities_from_group_or_componet to_subtract
    
    old_coplanar = find_coplanar_edges original_ents
    old_coplanar += find_coplanar_edges to_subtract_ents

    #Double intersect so intersection edges appear in both contexts.
    double_intersect original, to_subtract

    #Remove edges in original that are inside to_subtract and
    #edges in to_subtract that are outside original.
    to_remove = find_ents_to_remove original, to_subtract, true, false
    to_remove1 = find_ents_to_remove to_subtract, original, false, false
    original_ents.erase_entities to_remove
    to_subtract_ents.erase_entities to_remove1
    
    #Reverse all faces in to_subtract
    to_subtract_ents.each { |f| f.reverse! if f.is_a? Sketchup::Face }

    #Move to_subtract into original_ents and explode it.
    move_into original, to_subtract

    #Remove co-planar edges that occurred from the intersection (not those that
    #already existed)
    all_coplanar = find_coplanar_edges original_ents
    new_coplanar = all_coplanar - old_coplanar
    original_ents.erase_entities new_coplanar
    
    #Faces that where in the same plane in the different solids may have been
    #kept even if they are outside the expected resulting solid.
    #Remove all edges not binding 2 faces to get rid of them.
    original_ents.erase_entities original_ents.select { |e| e.is_a?(Sketchup::Edge) && e.faces.length < 2 }

    original.model.commit_operation if wrap_in_operator

    #Return whether result is solid or not
    is_solid? original

  end

  #Following methods are used internally and may be subject to change between
  #releases. Typically names may change.
  
  # Internal: Get the Entities object for either a Group or CompnentInstance.
  #
  # group_or_component - The group or ComponentInstance object.
  #
  # Returns an Entities object.
  def self.entities_from_group_or_componet(group_or_component)

    return group_or_component.entities if group_or_component.is_a?(Sketchup::Group)
    group_or_component.definition.entities

  end

  # Internal: Intersect solids twice to get intersection edges in both solids.
  #
  # ent0 - One of the groups or components to intersect.
  # ent1 - The other groups or components to intersect.
  #
  #Returns nothing.
  def self.double_intersect(ent0, ent1)

    ent0_ents = entities_from_group_or_componet ent0#NOTE: if possible, ignore nested groups and components here.
    ent1_ents = entities_from_group_or_componet ent1

    #Double intersect so intersection edges appear in both contexts.
    #NOTE: DOCUMENT (or fix): groups/components must be in the same drawing context for these transformations to work.
    ent0_ents.intersect_with false, ent0.transformation, ent1_ents, ent1.transformation, true, ent1
    ent1_ents.intersect_with false, ent1.transformation, ent0_ents, ent0.transformation, true, ent0

    nil
    
  end

  # Internal: Find entities to remove based on their position relative to the
  # other solid.
  def self.find_ents_to_remove(to_remove_in, refernce, inside, on_surface)

    to_remove_in_ents = entities_from_group_or_componet to_remove_in
    #NOTE: SOLIDS: look for faces with same vertices but reversed normal as a face in the other solid? solids might just touch.
    #NOTE: SOLIDS: also check faces inside solid. if all edges binding the face is kept the face will too be kept with current code. requires method to find *any* point that is inside the face.
    
    to_erase = []
    to_remove_in_ents.each do |e|
      next unless e.is_a? Sketchup::Edge
      midpoint = Geom.linear_combination 0.5, e.start.position, 0.5, e.end.position
      midpoint.transform! to_remove_in.transformation
      next if inside != inside_solid?(midpoint, refernce, inside == on_surface)
      to_erase << e
    end

    to_erase

  end

  # Internal: Change drawing context of group/component while keeping position.
  def self.move_into(destination, to_move)#NOTE: perhaps requires solids to be in same entities.
  
    #Create a new instance of the group/component.
    #Properties like material and attributes will be lost but should not be used anyway.
    #References to entities will be kept. Hooray!
    
    destination_ents = entities_from_group_or_componet destination
    
    to_move_def = to_move.is_a?(Sketchup::Group) ? to_move.entities.parent : to_move.definition
    
    trans_new = destination.transformation
    trans_old = to_move.transformation
    
    trans = trans_old*(trans_new.inverse)
    trans = trans_new.inverse*trans*trans_new#Transform transformation so it's relative to local and not global axes.
    
    temp = destination_ents.add_instance to_move_def, trans
    to_move.erase!
    temp.explode
    
  end

  #Find all co-planar edges in entities.
  def self.find_coplanar_edges(ents)
  
    ents.select do |e|
      next unless e.is_a? Sketchup::Edge#Next returns nil which evaluates to false, exuding this entity.
      next unless e.faces.length == 2
      f = e.faces[1]
      verts = e.faces[0].vertices
      
      !verts.any? { |v| f.classify_point(v.position) == Sketchup::Face::PointNotOnPlane}#NOTE: check materials and layers?
    end
    
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

      ent0 = sel[0]#NOTE: UI: sort after bounding box volume
      ent1 = sel[1]
      status = Solids.send @method_name, ent0, ent1
      
      UI.messagebox "Something went wrong :/\n\nOutput is not a solid." unless status

      #Go back to previous tool to make this tool feel like an operator
      #triggered directly from the menu rather than an actual tool.
      mod.tools.pop_tool#NOTE: UI: this and status text doesn't work properly. run this code without even activating tool instead of somehow de-activate it!

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
      self.reset#NOTE: UI: say "Done." in statusbar?
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
