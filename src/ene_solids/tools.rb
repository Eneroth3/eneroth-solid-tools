# Eneroth solid Tools

# Copyright Julia Christina Eneroth, eneroth3@gmail.com

module EneSolidTools

  # Internal: Class to base different UI tools on since most code is the same.
  class BaseTool

    def run_or_activate

      @not_a_solid_error = "Something went wrong :/\n\nOutput is not a solid."

      # If 2 solids and nothing else is selected, perform operation on those.
      # Otherwise activate tool and let user click them one at a time and also
      # define which one is one for asymmetrical operations.
      mod = Sketchup.active_model
      sel = mod.selection
      if sel.length == 2 && sel.all? { |e| Solids.is_solid? e }

        # Sort by approximate volume (based on bounding box) since no order is given.
        ent0 = sel[0]
        ent1 = sel[1]
        bb0 = ent0.bounds
        bb1 = ent1.bounds
        v0 = bb0.width * bb0.depth * bb0.height
        v1 = bb1.width * bb1.depth * bb1.height
        ent0, ent1 = ent1, ent0 if v1 > v0

        status = Solids.send(@method_name, ent0, ent1)

        if status
          # Tell user operations has been done.
          # Tell user to activate tool without a selection to chose order of
          # groups/components if operation was asymmetrical.
          # 0 timer to prevent status bar from being set by hovering command just clicked.
          UI.start_timer(0, false){ Sketchup.status_text = @statusbar_run_at_activate }
        else
          UI.messagebox @not_a_solid_error unless status
        end

      else

        Sketchup.active_model.select_tool(self)

      end

    end

    def activate

        #Activate tool.
        @ph = Sketchup.active_model.active_view.pick_helper
        @cursor = UI.create_cursor(File.join(File.dirname(EXTENSION.extension_path) , "ene_solids", @cursor_path), 2, 2)
        self.reset

    end

    def onSetCursor
      UI.set_cursor(@cursor)
    end

    def onMouseMove(flags, x, y, view)
      # Highlight hovered solid by making it the only selected entity.
      # Consistent to rotation, move and scale tool.
      mod = Sketchup.active_model
      sel = mod.selection
      sel.clear#! Sketchup API, I'm disappointed at you :(

      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return if picked == @ent0
      sel.add picked if Solids.is_solid?(picked)
    end

    def onLButtonDown(flags, x, y, view)
      # Get what was clicked, return if not a solid.
      @ph.do_pick(x, y)
      picked = @ph.best_picked
      return unless Solids.is_solid?(picked)

      if !@ent0
        #Select first group or component
        Sketchup.status_text = @statusbar1
        @ent0 = picked
      else
        #Select second group or component and run operator if first one is already selected.
        return if picked == @ent0
        ent0 = @ent0
        ent1 = picked
        status = Solids.send(@method_name, ent0, ent1)
        UI.messagebox @not_a_solid_error unless status
        self.reset
      end
    end

    def resume(view)
      Sketchup.status_text = !@ent0 ? @statusbar : @statusbar1
    end

    def onCancel(reason, view)
      self.reset
    end

    def reset
      Sketchup.status_text = @statusbar
      @ent0 = nil
    end

  end

  class UnionTool < BaseTool

    def initialize
      @cursor_path = "cursor_union.png"
      @statusbar = "Click original solid group/component to add to."
      @statusbar1 = "Click other solid group/component to add."
      @statusbar_run_at_activate = "Done."
      @method_name = :union
    end

  end

  class SubtractTool < BaseTool

    def initialize
      @cursor_path = "cursor_subtract.png"
      @statusbar = "Click original solid group/component to subtract from."
      @statusbar1 = "Click other solid group/component to subtract."
      @statusbar_run_at_activate = "Done. By instead activating tool without a selection you can chose what to subtract from what."
      @method_name = :subtract
    end

  end

  class TrimTool < BaseTool

    def initialize
      @cursor_path = "cursor_trim.png"
      @statusbar = "Click original solid group/component to trim."
      @statusbar1 = "Click other solid group/component to trim away."
      @statusbar_run_at_activate = "Done. By instead activating tool without a selection you can chose what to trim from what."
      @method_name = :trim
    end

  end

end
