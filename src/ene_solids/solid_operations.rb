module Eneroth
module SolidTools

# Solid Operations.
#
# For differences to native Solid Operations, see README.
module SolidOperations

  # Test if Group or Component is solid.
  #
  # If every edge in container binds an even number of faces the container is
  # considered solid. Nested containers are ignored.
  #
  # @param container [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Boolean]
  def self.solid?(container)
    return unless [Sketchup::Group, Sketchup::ComponentInstance].include?(container.class)
    ents = entities(container)

    !ents.any? { |e| e.is_a?(Sketchup::Edge) && e.faces.size.odd? }
  end

  # Test if point is inside of container.
  #
  # @param point [Geom::Point3d] Point in the same coordinate system as the
  #   container, not its internal coordinate system.
  # @param container [Sketchup::Group, Sketchup::ComponentInstance]
  # @param on_boundary [Boolean] Value to return if point is on the boundary
  #   (surface) itself.
  # @param verify_solid [Boolean] Test whether container is a solid, and return
  #   false if it isn't. This test can be omitted if the container is known to
  #   be a solid.
  #
  # @return [Boolean]
  def self.within?(point, container, on_boundary = true, verify_solid = true)
    return if verify_solid && !solid?(container)

    # Transform point coordinates into the local coordinate system of the
    # container. The original point should be defined relative to the axes of
    # the parent group or component, or, if the user has that drawing context
    # open, the global model axes.
    #
    # All method that return coordinates, e.g. #transformation and #position,
    # returns them local coordinates when the container isn't open and global
    # coordinates when it is. Usually you don't have to think about this but
    # as usual the (undocumented) attempts in the SketchUp API to dumb things
    # down makes it really odd and difficult to understand.
    point = point.transform(container.transformation.inverse)

    # Cast a ray from point in arbitrary direction an check how many times it
    # intersects the mesh.
    # Odd number means it's inside mesh, even means it's outside of it.

    # Use somewhat random vector to reduce risk of ray touching solid without
    # intersecting it.
    vector = Geom::Vector3d.new(234, 1343, 345)
    ray = [point, vector]

    intersection_points = entities(container).map do |face|
      next unless face.is_a?(Sketchup::Face)

      # If point is on face of solid, return value specified for that case.
      clasify_point = face.classify_point(point)
      return on_boundary if [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(clasify_point)

      intersection = Geom.intersect_line_plane(ray, face.plane)
      next unless intersection
      next if intersection == point

      # Intersection must be in the direction ray is casted to count.
      next unless (intersection - point).samedirection?(vector)

      # Check intersection's relation to face.
      # Counts as intersection if on face, including where cut-opening component cuts it.
      classify_intersection = face.classify_point(intersection)
      next unless [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(classify_intersection)

      intersection
    end
    intersection_points.compact!

    # If the ray intersects an edge or a vertex numerous intersections are
    # recorded for the same point.
    # These needs to be reduced to one.
    #
    # #make_unique can't be used on points since they are unique objects, even
    # when having the same coordinates.
    intersection_points = intersection_points.inject([]){ |a, p0| a.any?{ |p| p == p0 } ? a : a << p0 }

    intersection_points.size.odd?
  end

  # Unite one container with another.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifier [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Boolean] false denotes failure in algorithm.
  def self.union(target, modifier)

    #Check if both groups/components are solid.
    return if !solid?(target) || !solid?(modifier)

    # Older SU versions doesn't automatically make Groups unique when they are
    # edited.
    # Components on the other hand should off course not be made unique here.
    # That is up to the user to do manually if they want to.
    target.make_unique if target.is_a?(Sketchup::Group)

    # Copy the content of modifier into a temporary group where it can safely
    # modified without altering any other instances.
    # make_unique is not used since this would create a component visible in
    # the component browser if modifier is a component.
    temp_group = target.parent.entities.add_group
    move_into(temp_group, modifier)
    modifier = temp_group

    primary_ents = entities(target)
    secondary_ents = entities(modifier)

    # Remember co-planar edges for later.
    # FIXME: References in modifier are lost in SU2017.
    old_coplanar = find_coplanar_edges(primary_ents)
    old_coplanar += find_coplanar_edges(secondary_ents)

    # Double intersect so intersection edges appear in both contexts.
    add_intersection_edges(target, modifier)

    # Remove faces in both containers that are inside the other one's solid.
    # Remove faces that exists in both groups and have opposite orientation.
    to_remove = find_faces(target, modifier, true, false)
    to_remove1 = find_faces(modifier, target, true, false)
    corresponding = find_corresponding_faces(target, modifier, false)
    corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
    primary_ents.erase_entities(to_remove)
    secondary_ents.erase_entities(to_remove1)

    move_into(target, modifier)

    # Purge edges no longer not binding 2 edges.
    purge_edges(primary_ents)

    # Remove co-planar edges that occurred from the intersection and keep
    # those that already existed.
    all_coplanar = find_coplanar_edges(primary_ents)
    new_coplanar = all_coplanar - old_coplanar
    primary_ents.erase_entities(new_coplanar)

    weld_hack(primary_ents)

    solid?(target)
  end

  # Subtract one container from another.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifier [Sketchup::Group, Sketchup::ComponentInstance]
  # @param keep_modifer [Boolean] Keeping modifier makes this a trim operation.
  #
  # @return [Boolean] false denotes failure in algorithm.
  def self.subtract(target, modifier, keep_modifer = false)

    #Check if both groups/components are solid.
    return if !solid?(target) || !solid?(modifier)

    # Older SU versions doesn't automatically make Groups unique when they are
    # edited.
    # Components on the other hand should off course not be made unique here.
    # That is up to the user to do manually if they want to.
    target.make_unique if target.is_a?(Sketchup::Group)

    # Copy the content of modifier into a temporary group where it can safely
    # modified without altering any other instances.
    # make_unique is not used since this would create a component visible in
    # the component browser if modifier is a component.
    temp_group = target.parent.entities.add_group
    move_into(temp_group, modifier, keep_modifer)
    modifier = temp_group

    primary_ents = entities(target)
    secondary_ents = entities(modifier)

    # Remember co-planar edges for later.
    # FIXME: References in modifier are lost in SU2017.
    old_coplanar = find_coplanar_edges(primary_ents)
    old_coplanar += find_coplanar_edges(secondary_ents)

    # Double intersect so intersection edges appear in both contexts.
    add_intersection_edges(target, modifier)

    # Remove faces in target that are inside the modifier and faces in
    # modifier that are outside target.
    # Remove faces that exists in both groups and have opposite orientation.
    to_remove = find_faces(target, modifier, true, false)
    to_remove1 = find_faces(modifier, target, false, false)
    corresponding = find_corresponding_faces(target, modifier, true)
    corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
    primary_ents.erase_entities(to_remove)
    secondary_ents.erase_entities(to_remove1)

    # Reverse all faces in modifier
    secondary_ents.each { |f| f.reverse! if f.is_a? Sketchup::Face }

    move_into(target, modifier)

    # Purge edges no longer not binding 2 edges.
    purge_edges(primary_ents)

    # Remove co-planar edges that occurred from the intersection and keep
    # those that already existed.
    all_coplanar = find_coplanar_edges(primary_ents)
    new_coplanar = all_coplanar - old_coplanar
    primary_ents.erase_entities(new_coplanar)

    weld_hack(primary_ents)

    solid?(target)
  end

  # Trim one container from another.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifier [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Boolean] false denotes failure in algorithm.
  def self.trim(target, modifier)
    subtract(target, modifier, true)
  end

  # Intersect one container with another.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifier [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Boolean] false denotes failure in algorithm.
  def self.intersect(target, modifier)

    #Check if both groups/components are solid.
    return if !solid?(target) || !solid?(modifier)

    # Older SU versions doesn't automatically make Groups unique when they are
    # edited.
    # Components on the other hand should off course not be made unique here.
    # That is up to the user to do manually if they want to.
    target.make_unique if target.is_a?(Sketchup::Group)

    # Copy the content of modifier into a temporary group where it can safely
    # modified without altering any other instances.
    # make_unique is not used since this would create a component visible in
    # the component browser if modifier is a component.
    temp_group = target.parent.entities.add_group
    move_into(temp_group, modifier)
    modifier = temp_group

    primary_ents = entities(target)
    secondary_ents = entities(modifier)

    # Remember co-planar edges for later.
    # FIXME: References in modifier are lost in SU2017.
    old_coplanar = find_coplanar_edges(primary_ents)
    old_coplanar += find_coplanar_edges(secondary_ents)

    # Double intersect so intersection edges appear in both contexts.
    add_intersection_edges(target, modifier)

    # Remove faces in both containers that are outside the other one's solid.
    # Remove faces that exists in both groups and have opposite orientation.
    to_remove = find_faces(target, modifier, false, false)
    to_remove1 = find_faces(modifier, target, false, false)
    corresponding = find_corresponding_faces(target, modifier, false)
    corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
    primary_ents.erase_entities(to_remove)
    secondary_ents.erase_entities(to_remove1)

    move_into(target, modifier)

    # Purge edges no longer not binding 2 edges.
    purge_edges(primary_ents)

    # Remove co-planar edges that occurred from the intersection and keep
    # those that already existed.
    all_coplanar = find_coplanar_edges(primary_ents)
    new_coplanar = all_coplanar - old_coplanar
    primary_ents.erase_entities(new_coplanar)

    weld_hack(primary_ents)

    solid?(target)
  end

  #-----------------------------------------------------------------------------

  # Get the Entities object for group or component.
  #
  # Prior to SU 2015 there is no native Group#definition method.
  #
  # @param container [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Entities]
  def self.entities(container)
    if container.is_a?(Sketchup::Group)
      container.entities
    else
      container.definition.entities
    end
  end
  private_class_method :entities

  # Intersect containers and place intersection edges in both containers.
  #
  # @param container1 [Sketchup::Group, Sketchup::ComponentInstance]
  # @param container2 [Sketchup::Group, Sketchup::ComponentInstance]
  #
  # @return [Void]
  def self.add_intersection_edges(container1, container2)

    ents0 = entities(container1)
    ents1 = entities(container2)

    #Intersect twice to get coplanar faces.
    #Copy the intersection geometry to both solids.
    #Both solids must be in the same drawing context which they are moved to
    #in union and subtract method.
    temp_group = container1.parent.entities.add_group

    #Only intersect raw geometry, save time and avoid unwanted edges.
    ents0.intersect_with(false, container1.transformation, temp_group.entities, IDENTITY, true, ents1.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class) })
    ents1.intersect_with(false, container1.transformation.inverse, temp_group.entities, container1.transformation.inverse, true, ents0.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class) })

    move_into(container1, temp_group, true)
    move_into(container2, temp_group)

    nil
  end
  private_class_method :add_intersection_edges

  # Find an arbitrary point at a face.
  #
  # @param face [Sketchup::Face]
  #
  # @return [Geom::Point3d]
  def self.point_at_face(face)

    # Sometimes invalid faces gets created when intersecting.
    # These are removed when validity check run.
    return if face.area == 0

    # First find centroid and check if is within face (not in a hole).
    centroid = face.bounds.center
    return centroid if face.classify_point(centroid) == Sketchup::Face::PointInside

    # Find points by combining 3 adjacent corners.
    # If middle corner is convex point should be inside face (or in a hole).
    face.vertices.each_with_index do |v, i|
      c0 = v.position
      c1 = face.vertices[i-1].position
      c2 = face.vertices[i-2].position
      p  = Geom.linear_combination(0.95, c0, 0.05, c2)
      p  = Geom.linear_combination(0.95, p,  0.05, c1)

      return p if face.classify_point(p) == Sketchup::Face::PointInside
    end

    warn "Algorithm failed to find an arbitrary point on face."

    nil
  end
  private_class_method :point_at_face

  # Find faces based on them being interior or exterior to reference container.
  #
  # @param scope [Sketchup::Group, Sketchup::ComponentInstance]
  # @param reference [Sketchup::Group, Sketchup::ComponentInstance]
  # @param interior [Boolean] Whether faces interior to reference or faces exterior
  #   to reference should be selected.
  # @param on_surface [Boolean] I can't remember what this does, besides giving
  #   me a headache.
  #
  # @return [Array<Sketchup::Face>]
  def self.find_faces(scope, reference, interior, on_surface)
    entities(scope).select do |f|
      next unless f.is_a?(Sketchup::Face)
      point = point_at_face(f)
      next unless point
      point.transform!(scope.transformation)
      next if interior != within?(point, reference, interior == on_surface, false)

      true
    end
  end
  private_class_method :find_faces

  # Find pairs of faces duplicated between containers.
  #
  # @param container1 [Sketchup::Group, Sketchup::ComponentInstance]
  # @param container2 [Sketchup::Group, Sketchup::ComponentInstance]
  # @param orientation [Boolean, nil] True only returns faces with same
  #   orientation, false only returns faces with opposite orientation and nil
  #   skips orientation check.
  #
  # @return [Array<Sketchup::Face>] Odd faces are from container1 and even from
  #   container2.
  def self.find_corresponding_faces(container1, container2, orientation)

    faces = []

    entities(container1).each do |f0|
      next unless f0.is_a?(Sketchup::Face)
      normal0 = f0.normal.transform(container1.transformation)
      points0 = f0.vertices.map { |v| v.position.transform(container1.transformation) }
      entities(container2).each do |f1|
        next unless f1.is_a?(Sketchup::Face)
        normal1 = f1.normal.transform(container2.transformation)
        next unless normal0.parallel?(normal1)
        points1 = f1.vertices.map { |v| v.position.transform(container2.transformation) }
        next unless points0.all? { |v| points1.include?(v) }
        unless orientation.nil?
          next if normal0.samedirection?(normal1) != orientation
        end
        faces << f0
        faces << f1
      end
    end

    faces
  end
  private_class_method :find_corresponding_faces

  # Remove all edges binding less than 2 edges.
  #
  # @param entities [Sketchup::Entities]
  #
  # @return [Void]
  def self.purge_edges(entities)
    entities.erase_entities(entities.select { |e|
      next unless e.is_a?(Sketchup::Edge)
      next unless e.faces.size < 2
      true
    })

    nil
  end
  private_class_method :purge_edges

  # Move content of one container into another.
  #
  # Requires containers to be in the same drawing context.
  #
  # @param destination [Sketchup::Group, Sketchup::ComponentInstance]
  # @param to_move [Sketchup::Group, Sketchup::ComponentInstance]
  # @param keep_original [Boolean]
  #
  # @return [Void]
  def self.move_into(destination, to_move, keep_original = false)

    #Create a new instance of the group/component.
    #Properties like material and attributes will be lost but should not be used
    #anyway because group/component is exploded.
    #References to entities will be kept. Hooray!
    # Edit: As of SU 2017 references are not kept when exploding groups.

    destination_ents = entities destination

    to_move_def = to_move.is_a?(Sketchup::Group) ? to_move.entities.parent : to_move.definition

    trans_target = destination.transformation
    trans_old = to_move.transformation

    trans = trans_old*(trans_target.inverse)
    trans = trans_target.inverse*trans*trans_target

    temp = destination_ents.add_instance(to_move_def, trans)
    to_move.erase! unless keep_original
    temp.explode

    nil
  end
  private_class_method :move_into

  # Find coplanar edges with same material and layers on both sides.
  #
  # @param entities [Sketchup::Entities]
  #
  # @return [Array<Sketchup::Edge>]
  def self.find_coplanar_edges(entities)

    entities.select do |e|
      next unless e.is_a?(Sketchup::Edge)
      next unless e.faces.size == 2

      !e.faces[0].vertices.any? { |v|
        e.faces[1].classify_point(v.position) == Sketchup::Face::PointNotOnPlane
      }
    end

  end
  private_class_method :find_coplanar_edges

  # Weld overlapping edges.
  #
  # Sometimes SketchUp fails to weld these.
  #
  # @param entities [Sketchup::Entities]
  #
  # @return [Void]
  def self.weld_hack(entities)
    unless solid?(entities.parent)
      naked_edges = naked_edges entities

      temp_group = entities.add_group
      naked_edges.each do |e|
        temp_group.entities.add_line(e.start, e.end)
      end
      temp_group.explode
    end

    nil
  end
  private_class_method :weld_hack

  # Find edges only binding one face.
  #
  # @param entities [Sketchup::Entities]
  #
  # @return [Array<Sketchup::Edge>]
  def self.naked_edges(entities)
    entities = entities.to_a

    entities.select { |e| e.is_a?(Sketchup::Edge) && e.faces.size == 1 }
  end
  private_class_method :naked_edges

end
end
end
