module Eneroth
module SolidTools
module Tools

  Sketchup.require(File.join(PLUGIN_DIR, "solid_operations"))

  # Common private Superclass for all tools, as they are very similar.
  class Base

    NOT_SOLID_ERROR = "Something went wrong :/\n\nOutput is not a solid."

    # Track which of these tools is active so its menu entry/toolbar icon can be
    # highlighted.
    @@active_tool_class = nil

    # Perform operation or activate tool, depending on selection.
    #
    # If selection contains two or more solids, the tool is activated. Otherwise
    # the action is carried out diretcly, without changing active tool.
    #
    # @return [Void]
    def self.perform_or_activate
      model = Sketchup.active_model
      selection = model.selection
      if selection.size > 1 && selection.all? { |e| SolidOperations.is_solid?(e) }

        # Sort by bounding box volume since no order is given.
        # To manually define the what solid to modify and what to modify with
        # user must activate the tool.
        solids = selection.to_a.sort_by { |e| bb = e.bounds; bb.width * bb.depth * bb.height }.reverse

        model.start_operation(self::OPERATOR_NAME, true)
        primary = solids.shift
        until solids.empty?
          if !SolidOperations.send(self::METHOD_NAME, primary, solids.shift, false)
            model.commit_operation
            UI.messagebox(NOT_SOLID_ERROR)
            return
          end
        end
        model.commit_operation

        # Set status text inside 0 timer to override status set by hovering
        # the toolbar button.
        UI.start_timer(0, false){ Sketchup.status_text = self::STATUS_DONE }

      else
        Sketchup.active_model.select_tool(new)
      end

      nil
    end

    # Test whether this tool is active.
    #
    # @return [Boolean]
    def self.active?
      @@active_tool_class == self
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def activate
      @ph = Sketchup.active_model.active_view.pick_helper
      @cursor = UI.create_cursor(File.join(PLUGIN_DIR, "images", self.class::CURSOR_FILENAME), 2, 2)
      @@active_tool_class = self.class
      reset
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def deactivate(view)
      @@active_tool_class = nil
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onLButtonDown(flags, x, y, view)
      # Get what was clicked, return if not a solid.
      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return unless SolidOperations.is_solid?(picked)

      if !@primary
        Sketchup.status_text = self.class::STATUS_SECONDARY
        @primary = picked
      else
        return if picked == @primary
        secondary = picked
        view.model.start_operation(self.class::OPERATOR_NAME, true)
        if !SolidOperations.send(self.class::METHOD_NAME, @primary, secondary, false)
          UI.messagebox(NOT_SOLID_ERROR)
          reset
        end
        view.model.commit_operation
      end
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onMouseMove(flags, x, y, view)
      # Highlight hovered solid by making it the only selected entity.
      # Consistent to rotation, move and scale tool.
      selection = Sketchup.active_model.selection
      selection.clear
      selection.add(@primary) if @primary

      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return if picked == @primary
      return unless SolidOperations.is_solid?(picked)
      selection.add(picked)
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onCancel(reason, view)
      reset
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def onSetCursor
      UI.set_cursor(@cursor)
    end

    # @see http://ruby.sketchup.com/Sketchup/Tool.html
    def resume(view)
      Sketchup.status_text = !@primary ? self.class::STATUS_PRIMARY : self.class::STATUS_SECONDARY
    end

    # @see https://extensions.sketchup.com/pl/content/eneroth-tool-memory
    def ene_tool_cycler_icon
      File.join(PLUGIN_DIR, "images", "#{self.class::METHOD_NAME.to_s}.svg")
    end

    private

    # Reset tool to its original state.
    def reset
      Sketchup.active_model.selection.clear
      Sketchup.status_text = self.class::STATUS_PRIMARY
      @primary = nil
    end

  end
  private_constant :Base

  # Union Tool.
  class Union < Base
    CURSOR_FILENAME  = "cursor_union.png"
    STATUS_PRIMARY   = "Click primary solid group/component to add to."
    STATUS_SECONDARY = "Click secondary solid group/component to add with. Esc = Select new primary solid."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose which component to alter."
    OPERATOR_NAME    = "Union"
    METHOD_NAME      = :union
  end

  # Subtract Tool.
  class Subtract < Base
    CURSOR_FILENAME  = "cursor_subtract.png"
    STATUS_PRIMARY   = "Click primary solid group/component to subtract from."
    STATUS_SECONDARY = "Click secondary solid group/component to subtract with. Esc = Select new primary solid."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what to subtract from what."
    OPERATOR_NAME    = "Subtract"
    METHOD_NAME      = :subtract
  end

  # Trim Tool.
  class Trim < Base
    CURSOR_FILENAME  = "cursor_trim.png"
    STATUS_PRIMARY   = "Click primary solid group/component to trim."
    STATUS_SECONDARY = "Click secondary solid group/component to trim away. Esc = Select new primary solid."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what to trim from what."
    OPERATOR_NAME    = "Trim"
    METHOD_NAME      = :trim
  end

  # Intersect Tool.
  class Intersect < Base
    CURSOR_FILENAME  = "cursor_intersect.png"
    STATUS_PRIMARY   = "Click original solid group/component to intersect."
    STATUS_SECONDARY = "Click secondary solid group/component intersect with. Esc = Select new primary solid."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what solid to modify."
    OPERATOR_NAME    = "Intersect"
    METHOD_NAME      = :intersect
  end

end
end
end
