module Eneroth::SolidTools
module LGeom

# Namespace for methods related to SketchUp's native Geom::Vector3d class.
module LVector3d

  # Find an arbitrary unit vector that is not parallel to given vector.
  #
  # @param vector [Geom::Vector3d]
  #
  # @return [Geom::Vector3d]
  def self.arbitrary_non_parallel_vector(vector)
    vector.parallel?(Z_AXIS) ? X_AXIS : Z_AXIS
  end

  # Find an arbitrary unit vector that is perpendicular to given vector.
  #
  # @param vector [Geom::Vector3d]
  #
  # @return [Geom::Vector3d]
  def self.arbitrary_perpendicular_vector(vector)
    (vector * arbitrary_non_parallel_vector(vector)).normalize
  end

  # Return new vector transformed as a normal.
  #
  # Transforming a normal vector as a ordinary vector can give it a faulty
  # direction if the transformation is non-uniformly scaled or sheared. This
  # method assures the vector stays perpendicular to its perpendicular plane
  # when a transformation is applied.
  #
  # @param normal [Geom::Vector3d]
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # transform_as_normal VS native #transform
  #   skewed_tr = SkippyLib::LGeom::LTransformation.create_from_axes(
  #     ORIGIN,
  #     Geom::Vector3d.new(1, 0.3, 0),
  #     Geom::Vector3d.new(0, 1, 0),
  #     Geom::Vector3d.new(0, 0, 1)
  #   )
  #   normal = Y_AXIS
  #   puts "Transformed as vector: #{normal.transform(skewed_tr)}"
  #   puts "Transformed as normal: #{SkippyLib::LGeom::LVector3d.transform_as_normal(normal, skewed_tr)}"
  #
  # @return [Geom::Vector3d]
  def self.transform_as_normal(normal, transformation)
    tr = LTransformation.transpose(transformation).inverse

    normal.transform(tr).normalize
  end

end
end
end
