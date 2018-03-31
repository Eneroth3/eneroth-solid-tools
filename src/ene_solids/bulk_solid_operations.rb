module Eneroth
module SolidTools

Sketchup.require(File.join(PLUGIN_DIR, "solid_operations"))

# Solid Operations on multiple containers.
#
# For differences to native Solid Operations, see README.
module BulkSolidOperations

  # Test if containers are all solid.
  #
  # If every edge in container binds an even number of faces the container is
  # considered solid. Nested containers are ignored.
  #
  # @param containers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  #
  # @return [Boolean]
  def self.solid?(containers)
    containers.all? { |c| SolidOperations.solid?(c) }
  end

  # Test if point is inside of containers.
  #
  # @param point [Geom::Point3d]
  # @param containers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  # @param on_boundary [Boolean] Value to return if point is on the boundary
  #   (surface) itself.
  # @param verify_solid [Boolean] Test whether container is a solid, and return
  #   false if it isn't. This test can be omitted if the container is known to
  #   be a solid.
  # @param odd_even [Boolean] Count point within an even number of containers as
  #   being on the outside (as if an exclusion operation have been performed to
  #   containers).
  #
  # @return [Boolean]
  def self.within?(point, containers, on_boundary = true, verify_solid = true, odd_even = false)
    return if verify_solid && !solid?(containers)

    # REVIEW: If this allows even-odd check, perhaps there should also be an
    # exclusion operation for consistency. Should this method even exist?
    if odd_even
      containers.count { |c| SolidOperations.within?(point, c, on_boundary) }.odd?
    else
      containers.any? { |c| SolidOperations.within?(point, c, on_boundary) }
    end
  end

  # Unite multiple containers.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifiers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  #
  # @return [Boolean, nil] `nil` denotes failure in algorithm. `false` denotes one
  #   of the containers wasn't a solid.
  def self.union(target, modifiers)
    # Don't modify input array.
    modifiers = modifiers.dup

    until modifiers.empty?
      return nil unless SolidOperations.union(target, modifiers.shift)
    end

    true
  end

  # Subtract multiple container from multiple others.
  #
  # @param targets [Sketchup::Group, Sketchup::ComponentInstance,
  #   Array<Sketchup::Group, Sketchup::ComponentInstance>]
  # @param modifiers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  #
  # @return [Boolean, nil] `nil` denotes failure in algorithm. `false` denotes one
  #   of the containers wasn't a solid.
  def self.subtract(targets, modifiers)
    status = trim(targets, modifiers)
    return status unless status
    modifiers.first.parent.entities.erase_entities(modifiers)

    true
  end

  # Trim multiple containers from multiple others.
  #
  # @param targets [Sketchup::Group, Sketchup::ComponentInstance,
  #   Array<Sketchup::Group, Sketchup::ComponentInstance>]
  # @param modifiers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  #
  # @return [Boolean, nil] `nil` denotes failure in algorithm. `false` denotes one
  #   of the containers wasn't a solid.
  def self.trim(targets, modifiers)
    targets = [targets] unless targets.is_a?(Array)

    targets.each do |target|
      modifiers_dup = modifiers.dup
      until modifiers_dup.empty?
        return nil unless SolidOperations.trim(target, modifiers_dup.shift)
      end
    end
  end

  # Intersect one container multiple others.
  #
  # @param target [Sketchup::Group, Sketchup::ComponentInstance]
  # @param modifiers [Array<Sketchup::Group, Sketchup::ComponentInstance>]
  #
  # @return [Boolean, nil] `nil` denotes failure in algorithm. `false` denotes one
  #   of the containers wasn't a solid.
  def self.intersect(target, modifiers)
    # Don't modify input array.
    modifiers = modifiers.dup

    until modifiers.empty?
      return nil unless SolidOperations.intersect(target, modifiers.shift)
    end

    true
  end

end
end
end
