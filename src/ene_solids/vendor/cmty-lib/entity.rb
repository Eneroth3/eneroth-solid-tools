module Eneroth::SolidTools

# Namespace for methods related to SketchUp's native Entity classes.
module LEntity

  # Copy all attributes from another entity.
  #
  # @param entity [Sketchup::Entity]
  # @param source [Sketchup::Entity]
  #
  # Returns [Nothing]
  def self.copy_attributes(entity, source)
    # Entity#attribute_dictionaries returns nil instead of empty Array when
    # empty.
    dicts = source.attribute_dictionaries || []

    dicts.each do |dict|
      dict.each_pair do |key, value|
        entity.set_attribute(dict.name, key, value)
      end
    end

    nil
  end

  # Get definition used by instance.
  # For Versions before SU 2015 there was no Group#definition method.
  #
  # @param instance [Sketchup::ComponentInstance, Sketchup::Group, Sketchup::Image]
  #
  # @return [Sketchup::ComponentDefinition]
  def self.definition(instance)
    if instance.is_a?(Sketchup::ComponentInstance) ||
       (Sketchup.version.to_i >= 15 && instance.is_a?(Sketchup::Group))
      instance.definition
    else
      instance.model.definitions.find { |d| d.instances.include?(instance) }
    end
  end

  # Test if entity is either group or component instance.
  #
  # Since a group is a special type of component groups and component instances
  # can often be treated the same.
  #
  # @example
  #   # Show Information of the Selected Instance
  #   entity = Sketchup.active_model.selection.first
  #   if !entity
  #     puts "Selection is empty."
  #   elsif SkippyLib::LEntity.instance?(entity)
  #     puts "Instance's transformation is: #{entity.transformation}."
  #     puts "Instance's definition is: #{entity.definition}."
  #   else
  #     puts "Entity is not a group or component instance."
  #   end
  #
  # @param entity [Sketchup::Entity]
  #
  # @return [Boolean]
  def self.instance?(entity)
    entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
  end

  # Swap the definition used by an instance.
  #
  # As SketchUp doesn't support swapping group definitions or swap between a
  # group definition and a component definition, a new instance is
  # created in these cases.
  #
  # @param instance [Sketchup::ComponentInstance, Sketchup::Group]
  # @param definition [Sketchup::ComponentDefinition]
  #
  # @return [Sketchup::ComponentInstance, Sketchup::Group]
  def self.swap_definition(instance, definition)
    if instance.is_a?(Sketchup::Group) || definition.group?
      old_instance = instance
      instance = old_instance.parent.entities.add_instance(
        definition,
        old_instance.transformation
      )
      instance.material = old_instance.material
      instance.layer = old_instance.layer
      instance.hidden = old_instance.hidden?
      copy_attributes(instance, old_instance)
      old_instance.erase!
    else
      instance.definition = definition
    end

    instance
  end

end
end
