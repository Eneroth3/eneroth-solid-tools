# Eneroth solid Tools

module EneSolidTools

  # Various solid operations.
  #
  # To use these operators in your own project, copy the whole class into it
  # and into your own namespace (module).
  #
  # Face orientation is used on touching solids to determine whether faces
  # should be removed or not. Make sure faces are correctly oriented before
  # using.
  #
  # Differences from native solid tools:
  #  * Preserves original Group/ComponentInstance object with its own material,
  #    layer, attributes and other properties instead of creating a new one.
  #  * Preserves primitives inside groups/components with their own layers,
  #    attributes and other properties instead of creating new ones.
  #  * Ignores nested geometry, a house is for instance still a solid you can
  #    cut away a part of even if there's a cut-opening window component in the
  #    wall.
  #  * Operations on components alters all instances as expected instead of
  #    creating a new unique Group (that's what context menu > Make Unique is
  #    for).
  #  * Doesn't break material inheritance. If a Group/ComponentInstance itself
  #    is painted and child faces are not this will stay the same.
  #
  # A, Eneroth3, is much more of a UX person than an algorithm person. Someone
  # who is more of the latter might be able to optimize these operations and
  # make them more stable.
  #
  # If you contribute to the project, please don't mess up these differences
  # from the native solid tools. They are very much intended, and even the
  # reason why this project was started in the first place.
  class Solids

    # Check if a Group or ComponentInstance is solid. If every edge binds an
    # even faces it is considered a solid. Nested groups and components are
    # ignored.
    #
    # container - The Group or ComponentInstance to test.
    #
    # Returns Boolean.
    def self.is_solid?(container)
      return unless [Sketchup::Group, Sketchup::ComponentInstance].include?(container.class)
      ents = entities(container)

      !ents.any? { |e| e.is_a?(Sketchup::Edge) && e.faces.size.odd? }
    end

    # Check whether Point3d is inside, outside or the surface of solid.
    #
    # point                - Point3d to test (in the coordinate system the
    #                        container lies in, not internal coordinates).
    # container            - Group or component to test point to.
    # on_face_return_value - What to return when point is on face of solid.
    #                        (default: true)
    # verify_solid         - First verify that container actually is
    #                        a solid. (default true)
    #
    # Returns true if point is inside container and false if outside. Returns
    # on_face_return_value when point is on surface itself.
    # Returns nil if container isn't a solid and verify_solid is true.
    def self.inside_solid?(point, container, on_face_return_value = true, verify_solid = true)
      return if verify_solid && !is_solid?(container)

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
        return on_face_return_value if [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(clasify_point)

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
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the secondary one
    #                    should be added to.
    # secondary        - The secondary Group/ComponentInstance to add to the
    #                    primary one.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
    def self.union(primary, secondary, wrap_in_operator = true)

      #Check if both groups/components are solid.
      return if !is_solid?(primary) || !is_solid?(secondary)

      primary.model.start_operation("Union", true) if wrap_in_operator

      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # Copy the content of secondary into a temporary group where it can safely
      # modified without altering any other instances.
      # make_unique is not used since this would create a component visible in
      # the component browser if secondary is a component.
      temp_group = primary.parent.entities.add_group
      move_into(temp_group, secondary)
      secondary = temp_group

      primary_ents = entities(primary)
      secondary_ents = entities(secondary)

      # Remember co-planar edges for later.
      # FIXME: References in secondary are lost in SU2017.
      old_coplanar = find_coplanar_edges(primary_ents)
      old_coplanar += find_coplanar_edges(secondary_ents)

      # Double intersect so intersection edges appear in both contexts.
      intersect_wrapper(primary, secondary)

      # Remove faces in both containers that are inside the other one's solid.
      # Remove faces that exists in both groups and have opposite orientation.
      to_remove = find_faces(primary, secondary, true, false)
      to_remove1 = find_faces(secondary, primary, true, false)
      corresponding = find_corresponding_faces(primary, secondary, false)
      corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)

      move_into(primary, secondary)

      # Purge edges no longer not binding 2 edges.
      purge_edges(primary_ents)

      # Remove co-planar edges that occurred from the intersection and keep
      # those that already existed.
      all_coplanar = find_coplanar_edges(primary_ents)
      new_coplanar = all_coplanar - old_coplanar
      primary_ents.erase_entities(new_coplanar)

      weld_hack(primary_ents)

      primary.model.commit_operation if wrap_in_operator

      is_solid?(primary)
    end

    # Subtract one container from another.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the secondary one
    #                    should be subtracted from.
    # secondary        - The secondary Group/ComponentInstance to subtract from
    #                    the primary one.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    # keep_secondary   - Whether secondary should be left untouched. The same as
    #                    whether operation should be trim instead subtract.
    #                    (default: false)
    #
    # Returns true if result is a solid, false if something went wrong.
    def self.subtract(primary, secondary, wrap_in_operator = true, keep_secondary = false)

      #Check if both groups/components are solid.
      return if !is_solid?(primary) || !is_solid?(secondary)

      op_name = keep_secondary ? "Trim" : "Subtract"
      primary.model.start_operation(op_name, true) if wrap_in_operator

      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # Copy the content of secondary into a temporary group where it can safely
      # modified without altering any other instances.
      # make_unique is not used since this would create a component visible in
      # the component browser if secondary is a component.
      temp_group = primary.parent.entities.add_group
      move_into(temp_group, secondary, keep_secondary)
      secondary = temp_group

      primary_ents = entities(primary)
      secondary_ents = entities(secondary)

      # Remember co-planar edges for later.
      # FIXME: References in secondary are lost in SU2017.
      old_coplanar = find_coplanar_edges(primary_ents)
      old_coplanar += find_coplanar_edges(secondary_ents)

      # Double intersect so intersection edges appear in both contexts.
      intersect_wrapper(primary, secondary)

      # Remove faces in primary that are inside the secondary and faces in
      # secondary that are outside primary.
      # Remove faces that exists in both groups and have opposite orientation.
      to_remove = find_faces(primary, secondary, true, false)
      to_remove1 = find_faces(secondary, primary, false, false)
      corresponding = find_corresponding_faces(primary, secondary, true)
      corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)

      # Reverse all faces in secondary
      secondary_ents.each { |f| f.reverse! if f.is_a? Sketchup::Face }

      move_into(primary, secondary)

      # Purge edges no longer not binding 2 edges.
      purge_edges(primary_ents)

      # Remove co-planar edges that occurred from the intersection and keep
      # those that already existed.
      all_coplanar = find_coplanar_edges(primary_ents)
      new_coplanar = all_coplanar - old_coplanar
      primary_ents.erase_entities(new_coplanar)

      weld_hack(primary_ents)

      primary.model.commit_operation if wrap_in_operator

      is_solid?(primary)
    end

    # Trim one container using another.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance to trim using the
    #                    secondary one.
    # secondary        - The secondary Group/ComponentInstance to trim the
    #                    primary one with.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
    def self.trim(primary, secondary, wrap_in_operator = true)
      subtract(primary, secondary, wrap_in_operator, true)
    end

    # Intersect containers.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the intersect
    #                    intersect result will be put in.
    # secondary        - The secondary Group/ComponentInstance.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
    def self.intersect(primary, secondary, wrap_in_operator = true)

      #Check if both groups/components are solid.
      return if !is_solid?(primary) || !is_solid?(secondary)

      primary.model.start_operation("Intersect", true)if wrap_in_operator

      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # Copy the content of secondary into a temporary group where it can safely
      # modified without altering any other instances.
      # make_unique is not used since this would create a component visible in
      # the component browser if secondary is a component.
      temp_group = primary.parent.entities.add_group
      move_into(temp_group, secondary)
      secondary = temp_group

      primary_ents = entities(primary)
      secondary_ents = entities(secondary)

      # Remember co-planar edges for later.
      # FIXME: References in secondary are lost in SU2017.
      old_coplanar = find_coplanar_edges(primary_ents)
      old_coplanar += find_coplanar_edges(secondary_ents)

      # Double intersect so intersection edges appear in both contexts.
      intersect_wrapper(primary, secondary)

      # Remove faces in both containers that are outside the other one's solid.
      # Remove faces that exists in both groups and have opposite orientation.
      to_remove = find_faces(primary, secondary, false, false)
      to_remove1 = find_faces(secondary, primary, false, false)
      corresponding = find_corresponding_faces(primary, secondary, false)
      corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)

      move_into(primary, secondary)

      # Purge edges no longer not binding 2 edges.
      purge_edges(primary_ents)

      # Remove co-planar edges that occurred from the intersection and keep
      # those that already existed.
      all_coplanar = find_coplanar_edges(primary_ents)
      new_coplanar = all_coplanar - old_coplanar
      primary_ents.erase_entities(new_coplanar)

      weld_hack(primary_ents)

      primary.model.commit_operation if wrap_in_operator

      is_solid?(primary)
    end

    private

    # Internal: Get the Entities object for either a Group or CompnentInstance.
    # SU 2014 and lower doesn't support Group#definition.
    #
    # group_or_component - The group or ComponentInstance object.
    #
    # Returns an Entities object.
    def self.entities(group_or_component)
      if group_or_component.is_a?(Sketchup::Group)
        group_or_component.entities
      else
        group_or_component.definition.entities
      end
    end

    # Internal: Intersect solids and get intersection edges in both solids.
    #
    # ent0 - One of the groups or components to intersect.
    # ent1 - The other groups or components to intersect.
    #
    #Returns nothing.
    def self.intersect_wrapper(ent0, ent1)

      ents0 = entities(ent0)
      ents1 = entities(ent1)

      #Intersect twice to get coplanar faces.
      #Copy the intersection geometry to both solids.
      #Both solids must be in the same drawing context which they are moved to
      #in union and subtract method.
      temp_group = ent0.parent.entities.add_group

      #Only intersect raw geometry, save time and avoid unwanted edges.
      ents0.intersect_with(false, ent0.transformation, temp_group.entities, temp_group.transformation, true, ents1.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class) })
      ents1.intersect_with(false, ent0.transformation, temp_group.entities, temp_group.transformation, true, ents0.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class) })

      move_into(ent0, temp_group, true)
      move_into(ent1, temp_group)

      nil
    end

    # Internal: Find arbitrary point inside face, not on its edge or corner.
    #
    # face - The face to find a point in.
    #
    # Returns a Point3d object.
    def self.point_in_face(face)

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

    # Internal: Find faces to remove based on their position relative to the
    # other solid.
    def self.find_faces(source, reference, inside, on_surface)
      entities(source).select do |f|
        next unless f.is_a?(Sketchup::Face)
        point = point_in_face(f)
        next unless point
        point.transform!(source.transformation)
        next if inside != inside_solid?(point, reference, inside == on_surface, false)
        true
      end
    end

    # Internal: Find faces that exists with same location in both contexts.
    #
    # same_orientation - true to only return those oriented the same direction,
    #                    false to only return those oriented the opposite
    #                    direction and nil to skip direction check.
    #
    # Returns an array of faces, every second being in each drawing context.
    def self.find_corresponding_faces(ent0, ent1, same_orientation)

      faces = []

      entities(ent0).each do |f0|
        next unless f0.is_a?(Sketchup::Face)
        normal0 = f0.normal.transform(ent0.transformation)
        points0 = f0.vertices.map { |v| v.position.transform(ent0.transformation) }
        entities(ent1).each do |f1|
          next unless f1.is_a?(Sketchup::Face)
          normal1 = f1.normal.transform(ent1.transformation)
          next unless normal0.parallel?(normal1)
          points1 = f1.vertices.map { |v| v.position.transform(ent1.transformation) }
          next unless points0.all? { |v| points1.include?(v) }
          unless same_orientation.nil?
            next if normal0.samedirection?(normal1) != same_orientation
          end
          faces << f0
          faces << f1
        end
      end

      faces
    end

    # Internal: Remove all edges binding less than 2 edges.
    def self.purge_edges(ents)
      ents.erase_entities(ents.select { |e|
        next unless e.is_a?(Sketchup::Edge)
        next unless e.faces.size < 2
        true
      })
    end

    # Internal: Merges groups/components.
    # Requires both groups/components to be in the same drawing context.
    def self.move_into(destination, to_move, keep = false)

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
      to_move.erase! unless keep
      temp.explode

    end

    # Internal: Find all co-planar edges in entities with both faces having same
    # material and layer.
    def self.find_coplanar_edges(ents)

      ents.select do |e|
        next unless e.is_a?(Sketchup::Edge)
        next unless e.faces.size == 2

        !e.faces[0].vertices.any? { |v|
          e.faces[1].classify_point(v.position) == Sketchup::Face::PointNotOnPlane
        }
      end

    end

    # Internal: Sometimes naked overlapping un-welded edges are formed in SU.
    # This method tried to weld them.
    #
    # entities - The entities object to weld in.
    #
    # returns nothing
    def self.weld_hack(entities)
      unless is_solid?(entities.parent)
        naked_edges = naked_edges entities

        temp_group = entities.add_group
        naked_edges.each do |e|
          temp_group.entities.add_line(e.start, e.end)
        end
        temp_group.explode
      end

      nil
    end

    # Internal: Find edges that's only binding one face.
    #
    # entities - An Entities object or an Array of Entity objects.
    #
    # Returns an Array of Edges.
    def self.naked_edges(entities)
      entities = entities.to_a

      entities.select { |e| e.is_a?(Sketchup::Edge) && e.faces.size == 1 }
    end

  end

end
