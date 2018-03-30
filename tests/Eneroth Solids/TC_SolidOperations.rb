require 'testup/testcase'

class TC_SolidOperations < TestUp::TestCase

  SolidOperations = Eneroth::SolidTools::SolidOperations

  def setup
    #...
  end

  def teardown
    #...
  end

  def support_dir
    basename = File.basename(__FILE__, ".*")
    path = File.dirname(__FILE__)

    File.join(path, basename)
  end

  def open_model(rel_path)
    test_model = File.join(support_dir, rel_path)
    disable_read_only_flag_for_test_models
    Sketchup.open_file(test_model)
    restore_read_only_flag_for_test_models
  end

  #-----------------------------------------------------------------------------

  def test_union__components
    open_model("Horizontally Overlapping Cube Components.skp")

    model = Sketchup.active_model
    target = model.entities.find    { |e| e.name == "Target" }
    modifier = model.entities.find  { |e| e.name == "Modifier" }
    bystander = model.entities.find { |e| e.name == "Bystander" }

    target_definition = target.definition
    target_layer = target.layer
    target_material = target.material
    target_transformation = target.transformation

    model.start_operation("Union", true)
    SolidOperations.union(target, modifier)
    model.commit_operation

    assert(target.valid?, "Target should remain in model.")
    refute(modifier.valid?, "Modifier should be removed.")
    assert(target.manifold?, "Target should be solid")
    assert(target.definition = target_definition, "Target should retain its definition object.")
    assert(bystander.definition = target_definition, "Bystander should retain its definition object.")
    assert(target.layer = target_layer, "Target should retain its layer.")
    assert(target.material = target_material, "Target should retain its material.")
    assert(target.transformation = target_transformation, "Target should retain its transformation.")
    assert(1 == model.definitions.size, "Definition count should remain the same.")
    msg = "Coplanar faces between containers, here top and bottom, should be merged."
    assert_equal(10, target.definition.entities.grep(Sketchup::Face).size, msg)

    close_active_model
  end

  def test_union__groups
    open_model("Horizontally Overlapping Cube Groups.skp")

    model = Sketchup.active_model
    target = model.entities.find    { |e| e.name == "Target" }
    modifier = model.entities.find  { |e| e.name == "Modifier" }
    bystander = model.entities.find { |e| e.name == "Bystander" }

    bystander_definition = bystander.definition
    bystander_volume = bystander.volume

    model.start_operation("Union", true)
    SolidOperations.union(target, modifier)
    model.commit_operation

    assert(target.valid?, "Target should remain in model.")
    assert(target.manifold?, "Target should be solid")
    refute(modifier.valid?, "Modifier should be removed.")
    assert(
      bystander.definition == bystander_definition,
      "Bystander group instance should retain its definition. "\
      "Target group should silently be made unique if there are other instances of its definition."
    )
    assert(
      bystander.volume == bystander_volume,
      "Bystander group instance should retain its volume. "\
      "Target group should silently be made unique if there are other instances of its definition."
    )

    close_active_model
  end

  # TODO: Perform similar tests on subtract, trim and intersect too.
  #   Components should never be implicitly made unique.
  #   Groups should be silently made unique (if there are other instances elsewhere).

  def test_trim__nested_containers
    open_model("House.skp")

    model = Sketchup.active_model
    cutters = model.definitions["Cutter"].instances
    building_volumes = model.entities.to_a - cutters

    model.start_operation("Subtract", true)
    building_volumes.each do |b|
      cutters.each do |c|
        SolidOperations.trim(b, c)
      end
    end
    model.entities.erase_entities(cutters)
    model.commit_operation

    assert(
      building_volumes.all? { |b| SolidOperations.solid?(b) },
      "Building volumes should still be regarded solid."
    )

    close_active_model
  end

  def test_union__retain_coplanar
    open_model("Horizontally Overlapping Cube Components Coplanar Edge.skp")

    model = Sketchup.active_model
    target = model.entities.find    { |e| e.name == "Target" }
    modifier = model.entities.find  { |e| e.name == "Modifier" }

    model.start_operation("Union", true)
    SolidOperations.union(target, modifier)
    model.commit_operation

    msg =
      "Top and bottom should be merged, "\
      "but pre-existing edge on side should be kept."
    assert_equal(11, target.definition.entities.grep(Sketchup::Face).size, msg)

    close_active_model
  end

  # TODO: Test solidity.
  #   Simple cubes are considered solid.
  #   Two cubes touching at an edge (edge binding 4 faces) are considered solid.
  #   Nested containers doesn't stop the parent from being considered solid,
  #     regardless of whether they are solid themselves or not.

  # TODO: Test within.
  #   A few basic primitives.
  #   Test point on boundary face.
  #   Test point on edge.
  #   Test when inside inner void.

end
