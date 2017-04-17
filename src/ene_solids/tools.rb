# Eneroth solid Tools

# Copyright Julia Christina Eneroth, eneroth3@gmail.com

module EneSolidTools

  class BaseTool

    NOT_SOLID_ERROR = "Something went wrong :/\n\nOutput is not a solid."

    # Since SketchUp's built checking of tools in menus seems to fail for tools
    # that are subclasses the active tool's class has to be tracked by the
    # plugin.
    @@active_tool_class = nil

    # Perform solid operation on selection if it consists of two or more solids
    # and nothing else, otherwise activate tool.
    def self.perform_or_activate

      selection = Sketchup.active_model.selection
      if selection.size > 1 && selection.all? { |e| Solids.is_solid?(e) }

        # Sort by bounding box volume since no order is given.
        # To manually define the what solid to modify and what to modify with
        # user must activate the tool.
        solids = selection.to_a.sort_by { |e| bb = e.bounds; bb.width * bb.depth * bb.height }.reverse

        # TODO: Create operator here. Commit after or on failure.
        primary = solids.shift
        until solids.empty?
          if !Solids.send(self::METHOD_NAME, primary, solids.shift)
            UI.messagebox(NOT_SOLID_ERROR)
            return
          end
        end

        # Set status text inside 0 timer to override status set by hovering
        # the toolbar button.
        UI.start_timer(0, false){ Sketchup.status_text = self::STATUS_DONE }

      else
        Sketchup.active_model.select_tool(new)
      end
    end

    # Check whether this is the active tool.
    def self.active?
      @@active_tool_class == self
    end

    # SketchUp Tool Interface

    def activate
      @ph = Sketchup.active_model.active_view.pick_helper
      @cursor = UI.create_cursor(File.join(EXTENSION_DIR, self.class::CURSOR_FILENAME), 2, 2)
      @@active_tool_class = self.class
      reset
    end

    def deactivate(view)
      @@active_tool_class = nil
    end

    def onLButtonDown(flags, x, y, view)
      # Get what was clicked, return if not a solid.
      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return unless Solids.is_solid?(picked)

      if !@primary
        Sketchup.status_text = self.class::STATUS_SECONDARY
        @primary = picked
      else
        return if picked == @primary
        secondary = picked
        if !Solids.send(self.class::METHOD_NAME, @primary, secondary)
          UI.messagebox(NOT_SOLID_ERROR)
          reset
        end
      end
    end

    def onMouseMove(flags, x, y, view)
      # Highlight hovered solid by making it the only selected entity.
      # Consistent to rotation, move and scale tool.
      selection = Sketchup.active_model.selection
      selection.clear
      selection.add(@primary) if @primary

      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return if picked == @primary
      return unless Solids.is_solid?(picked)
      selection.add(picked)
    end

    def onCancel(reason, view)
      reset
    end

    def onSetCursor
      UI.set_cursor(@cursor)
    end

    def resume(view)
      Sketchup.status_text = !@primary ? self.class::STATUS_PRIMARY : self.class::STATUS_SECONDARY
    end

    private

    def reset
      Sketchup.active_model.selection.clear
      Sketchup.status_text = self.class::STATUS_PRIMARY
      @primary = nil
    end

  end

  class UnionTool < BaseTool
    CURSOR_FILENAME  = "cursor_union.png"
    STATUS_PRIMARY   = "Click original solid group/component to add to."
    STATUS_SECONDARY = "Click other solid group/component to add."# TODO: Add Esc = Drop selection/primary/something.
    STATUS_DONE      = "Done."
    METHOD_NAME      = :union
  end

  class SubtractTool < BaseTool
    CURSOR_FILENAME  = "cursor_subtract.png"
    STATUS_PRIMARY   = "Click original solid group/component to subtract from."
    STATUS_SECONDARY = "Click other solid group/component to subtract."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what to subtract from what."
    METHOD_NAME      = :subtract
  end

  class TrimTool < BaseTool
    CURSOR_FILENAME  = "cursor_trim.png"
    STATUS_PRIMARY   = "Click original solid group/component to trim."
    STATUS_SECONDARY = "Click other solid group/component to trim away."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what to trim from what."
    METHOD_NAME      = :trim
  end

  class IntersectTool < BaseTool
    CURSOR_FILENAME  = "cursor_intersect.png"
    STATUS_PRIMARY   = "Click original solid group/component to intersect."
    STATUS_SECONDARY = "Click other solid group/component intersect with."
    STATUS_DONE      = "Done. By instead activating tool without a selection you can chose what solid to modify."
    METHOD_NAME      = :intersect
  end

end
