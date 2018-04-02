module Eneroth::SolidTools
module LGeom

# Namespace for methods related to planes.
#
# A plane can either be expressed as an Array of a point and vector or as an
# Array of 4 Floats defining the coefficients of the plane equation.
# SketchUp' API methods accepts both types.
#
# This module is however designed so you don't have to think about these formats.
# Instead of e.g. having methods to convert between the two formats all methods
# accept them directly.
module LPlane

  # Determine the unit normal vector for a plane.
  #
  # @param plane [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  #
  # @return [Geom::Vector3d]
  def self.normal(plane)
    raise ArgumentError, "Object doesn't represent a plane." unless valid?(plane)

    return plane[1].normalize if plane.size == 2
    a, b, c = plane

    Geom::Vector3d.new(a, b, c).normalize
  end

  # Test if two planes are plane parallel.
  #
  # @param plane_a [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  # @param plane_b [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  #
  # @return [Boolean]
  def self.parallel?(plane_a, plane_b)
    raise ArgumentError, "Object 'plane_a' doesn't represent a plane." unless valid?(plane_a)
    raise ArgumentError, "Object 'plane_b' doesn't represent a plane." unless valid?(plane_b)

    normal(plane_a).parallel?(normal(plane_b))
  end

  # Find arbitrary point on plane.
  #
  # @param plane [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  #
  # @return [Geom::Point3d]
  def self.point(plane)
    raise ArgumentError, "Object doesn't represent a plane." unless valid?(plane)

    return plane[0] if plane.size == 2
    a, b, c, d = plane
    v = Geom::Vector3d.new(a, b, c)

    ORIGIN.offset(v, -d)
  end

  # Test if two planes are the same.
  #
  # @param plane_a [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  # @param plane_b [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  # @param incldue_flipped [Boolean]
  #
  # @return [Boolean]
  def self.same?(plane_a, plane_b, incldue_flipped = false)
    raise ArgumentError, "Object 'plane_a' doesn't represent a plane." unless valid?(plane_a)
    raise ArgumentError, "Object 'plane_b' doesn't represent a plane." unless valid?(plane_b)

    return false unless point(plane_a).on_plane?(plane_b)
    return false unless parallel?(plane_a, plane_b)

    incldue_flipped || normal(plane_a).samedirection?(normal(plane_b))
  end

  # Transform plane.
  #
  # @param plane [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  # @param transformation [Geom::Transformation]
  #
  # @return [Array(Geom::Point3d, Geom::Vector3d)]
  def self.transform_plane(plane, transformation)
    raise ArgumentError, "Object doesn't represent a plane." unless valid?(plane)
    raise ArgumentError, "Requires transformation." unless transformation.is_a?(Geom::Transformation)

    [
      point(plane).transform(transformation),
      LVector3d.transform_as_normal(normal(plane), transformation)
    ]
  end

  # Test if Object represents a plane.
  #
  # In the SketchUp Ruby API a plane can either be expressed as an Array of 4
  # floats, or as an Array of one Point3d and one Vector3d.
  #
  # @return [Boolean]
  def self.valid?(plane)
    return false unless plane.is_a?(Array)

    (plane.size == 4 && plane.all? { |e| e.is_a?(Numeric) }) ||
      (plane.size == 2 && plane[0].is_a?(Geom::Point3d) && plane[1].is_a?(Geom::Vector3d))
  end

end
end
end
