module Eneroth
module SolidTools

Sketchup.require(File.join(PLUGIN_DIR, "solid_operations"))
Sketchup.require(File.join(PLUGIN_DIR, "bulk_solid_operations"))

module Tools

  # All tools.
  class Base

    NOT_SOLID_ERROR = "Something went wrong :/\n\nOutput is not a solid.".freeze

    # Track which of these tools is active so its menu entry/toolbar icon can be
    # highlighted.
    @@active_tool_class = nil

    # Perform operation or activate tool, depending on selection.
    #
    # If selection contains two or more solids, the action is instantly
    # performed, with an arbitrary target. Otherwise the tool is activated.
    #
    # @return [Void]
    def self.perform_or_activate
      model = Sketchup.active_model
      selection = model.selection
      if BulkSolidOperations.solid?(selection) && selection.size > 1
        # Sort by volume for a little less arbitrary result.
        # Don't use native #volume method as SketchUp may not consider objects
        # to be solids (there can be nested containers).
        solids = selection.to_a.sort_by { |e| -bb_volume(e.bounds) }

        target = solids.shift
        operate(target, solids)

        delayed_status(self::STS_DONE_INSTANT)
      else
        model.select_tool(new)
      end

      nil
    end

    # Test whether this tool is active.
    #
    # @return [Boolean]
    def self.active?
      @@active_tool_class == self
    end

    def initialize
      # For this class this is a single Entity is target but for subclass an
      # Array of Entity objects is the targets.
      # All references to target/targets need to be in simple accessor like
      # methods that can be easily overridden.
      @target = nil

      @ph     = Sketchup.active_model.active_view.pick_helper
      @cursor = create_cursor
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def activate
      @@active_tool_class = self.class
      display_status
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def deactivate(_view)
      @@active_tool_class = nil
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onLButtonDown(_flags, x, y, _view)
      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return unless SolidOperations.solid?(picked)

      if picking_target?
        pick_target(picked)
        display_status
      else
        return if target?(picked)
        pick_modifier(picked)
        # Status text isn't changed as user can keep pick modifiers to
        # repeatedly perform action.
      end
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onMouseMove(_flags, x, y, _view)
      # Highlight hovered solid by making it the only selected entity.
      # Consistent to rotation, move and scale tool.
      selection = Sketchup.active_model.selection
      selection.clear

      select_target(selection) unless picking_target?

      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return if target?(picked)
      return unless SolidOperations.solid?(picked)
      selection.add(picked)
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onCancel(_reason, _view)
      reset
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onSetCursor
      UI.set_cursor(@cursor)
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def resume(_view)
      display_status
    end

    # @see https://extensions.sketchup.com/pl/content/eneroth-tool-memory
    def ene_tool_cycler_icon
      File.join(PLUGIN_DIR, "images", "#{self.class.identifier}.svg")
    end

    # Should be protected

    # Calculate volume of bounding box.
    #
    # @param bb [Geom::BoundingBox]
    #
    # @return [Float] - volume in cubic inches.
    def self.bb_volume(bb)
      bb.width * bb.depth * bb.height
    end

    # Set statusbar text that stays until the user performs an action changing
    # it, e.g. hover a toolbar.
    #
    # @param text [String]
    #
    # @return [Void]
    def self.delayed_status(text)
      # Set status text inside 0 timer to override status set by operation
      # finishing.
      UI.start_timer(0, false) { Sketchup.status_text = text }

      nil
    end

    # Get operation identifier for current tool.
    #
    # @return [Symbol]
    def self.identifier
      # Based on Tool's class name.
      name.split("::").last.downcase.to_sym
    end

    # Perform tool's operation.
    #
    # Show feedback if operation failed.
    #
    # @return [Void]
    def self.operate(target, modifiers)
      modifiers = [modifiers] unless modifiers.is_a?(Array)

      model = Sketchup.active_model
      model.start_operation(self::OPERATOR_NAME, true)
      unless BulkSolidOperations.send(identifier, target, modifiers)
        UI.messagebox(NOT_SOLID_ERROR)
        reset
      end
      model.commit_operation

      nil
    end

    private

    # Create cursor.
    #
    # @return [Integer]
    def create_cursor
      UI.create_cursor(
        File.join(PLUGIN_DIR, "images", "cursor_#{self.class.identifier}.png"),
        2,
        2
      )
    end

    # Check if entity is set to be target.
    def target?(solid)
      @target == solid
    end

    # Pick modifier and perform operation with it.
    def pick_modifier(solid)
      self.class.operate(@target, solid)
    end

    # Pick a solid to use as target.
    def pick_target(solid)
      @target = solid
    end

    # Check target or modifier is being picked.
    def picking_target?
      !@target
    end

    # Reset tool to its original state.
    def reset
      Sketchup.active_model.selection.clear
      reset_target
      display_status
    end

    # Reset target to clean state.
    def reset_target
      @target = nil
    end

    # Add target to model selection.
    def select_target(selection)
      selection.add(@target)
    end

    # Display status text
    def display_status
      Sketchup.status_text = picking_target? ? self.class::STS_PICK_TARGET : self.class::STS_PICK_MODIFIER
    end

  end
  private_constant :Base

  # Tools that support multiple target solids.
  class MultiTarget < Base

    # Always activate tool, regardless of selection.
    def self.perform_or_activate
      model = Sketchup.active_model
      model.select_tool(new)

      nil
    end

    def initialize
      super
      selection = Sketchup.active_model.selection
      @targets = selection.select { |s| SolidOperations.solid?(s) }
    end

    # Check if entity is set to be target.
    def target?(solid)
      @targets.include?(solid)
    end

    # Pick modifier and perform operation with it.
    def pick_modifier(solid)
      self.class.operate(@targets, solid)
    end

    # Pick a solid to use as target.
    def pick_target(solid)
      @targets << solid
    end

    # Check target or modifier is being picked.
    def picking_target?
      @targets.empty?
    end

    # Reset target to clean state.
    def reset_target
      @targets.clear
    end

    # Add target to model selection.
    def select_target(selection)
      @targets.each { |t| selection.add(t) }
    end
  end
  private_constant :MultiTarget

  # Union Tool.
  class Union < Base
    # TODO: Extract strings to separate language file, e.g. using Ordbok.
    # Have these classes being empty bodied and get strings directly in BaseTool
    # based on identifier.
    STS_PICK_TARGET   = "Click primary solid group/component to add to.".freeze
    STS_PICK_MODIFIER =
      "Click secondary solid group/component to add with. Esc = Select new primary solid.".freeze
    STS_DONE_INSTANT  =
      "Done. By instead activating tool without a selection you can chose which component to alter.".freeze
    OPERATOR_NAME     = "Union".freeze
  end

  # Subtract Tool.
  class Subtract < MultiTarget
    STS_PICK_TARGET   = "Click primary solid group/component to subtract from.".freeze
    STS_PICK_MODIFIER = "Click secondary solid group/component to subtract with. Esc = Select new primary solid.".freeze
    STS_DONE_INSTANT  =
      "Done. By instead activating tool without a selection you can chose what to subtract from what.".freeze
    OPERATOR_NAME     = "Subtract".freeze
  end

  # Trim Tool.
  class Trim < MultiTarget
    STS_PICK_TARGET   = "Click primary solid group/component to trim.".freeze
    STS_PICK_MODIFIER = "Click secondary solid group/component to trim away. Esc = Select new primary solid.".freeze
    STS_DONE_INSTANT  =
      "Done. By instead activating tool without a selection you can chose what to trim from what.".freeze
    OPERATOR_NAME     = "Trim".freeze
  end

  # Intersect Tool.
  class Intersect < Base
    STS_PICK_TARGET   = "Click original solid group/component to intersect.".freeze
    STS_PICK_MODIFIER = "Click secondary solid group/component intersect with. Esc = Select new primary solid.".freeze
    STS_DONE_INSTANT  =
      "Done. By instead activating tool without a selection you can chose what solid to modify.".freeze
    OPERATOR_NAME     = "Intersect".freeze
  end

end
end
end
