module Eneroth::SolidTools

# Namespace for methods related to SketchUp's native Face class.
module LFace

  # Find an arbitrary point within face.
  #
  # @param face [Sketchup::Face]
  #
  # @return [Geom::Point3d, nil] nil is returned for zero area faces.
  def self.arbitrary_interior_point(face)
    return if face.area.zero?

    # In rare situations PolygonMesh.polygon_points return points on a line,
    # which would lead to a point on the face boundary being returned rather
    # than one within face.
    index = 1
    points = nil
    loop do
      points = face.mesh.polygon_points_at(index)
      index += 1
      break unless points[0].on_line?(points[1], points[2])
    end

    Geom.linear_combination(
      0.5,
      Geom.linear_combination(0.5, points[0], 0.5, points[1]),
      0.5,
      points[2]
    )
  end

  # Test if point is within a face.
  #
  # @param point [Geom::Point3d]
  # @param face [Sketchup::Face]
  # @param include_boundary [Boolean]
  #
  # @return [Boolean]
  def self.includes_point?(face, point, include_boundary = true)
    pc = face.classify_point(point)
    return include_boundary if [Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(pc)

    pc == Sketchup::Face::PointInside
  end

  # Get an array of all the interior loops of a face.
  #
  # If the face has no interior loops (holes in it) the array will be empty.
  #
  # @param face [SketchUp::Face]
  #
  # @example
  #   ents = Sketchup.active_model.active_entities
  #   outer_face = ents.add_face(
  #     Geom::Point3d.new(0,   0,   0),
  #     Geom::Point3d.new(0,   1.m, 0),
  #     Geom::Point3d.new(1.m, 1.m, 0),
  #     Geom::Point3d.new(1.m, 0,   0)
  #   )
  #   inner_face = ents.add_face(
  #     Geom::Point3d.new(0.25.m, 0.25.m, 0),
  #     Geom::Point3d.new(0.25.m, 0.75.m, 0),
  #     Geom::Point3d.new(0.75.m, 0.75.m, 0),
  #     Geom::Point3d.new(0.75.m, 0.25.m, 0)
  #   )
  #   SkippyLib::LFace.inner_loops(outer_face)
  #
  # @return [Array<Sketchup::Loop>]
  def self.inner_loops(face)
    face.loops - [face.outer_loop]
  end

  # Find the exterior face that a face forms a hole within, or nil if face isn't
  # inside another face.
  #
  # @param face [SketchUp::Face]
  #
  # @example
  #   ents = Sketchup.active_model.active_entities
  #   ents.add_face(
  #     Geom::Point3d.new(0,   0,   0),
  #     Geom::Point3d.new(0,   1.m, 0),
  #     Geom::Point3d.new(1.m, 1.m, 0),
  #     Geom::Point3d.new(1.m, 0,   0)
  #   )
  #   inner_face = ents.add_face(
  #     Geom::Point3d.new(0.25.m, 0.25.m, 0),
  #     Geom::Point3d.new(0.25.m, 0.75.m, 0),
  #     Geom::Point3d.new(0.75.m, 0.75.m, 0),
  #     Geom::Point3d.new(0.75.m, 0.25.m, 0)
  #   )
  #   outer_face = SkippyLib::LFace.wrapping_face(inner_face)
  #
  # @return [Sketchup::Face, nil]
  def self.wrapping_face(face)
    (face.edges.map(&:faces).inject(:&) - [face]).first
  end

end
end
