module Eneroth
module SolidTools

  if Sketchup.version.to_i < REQUIRED_SU_VERSION
    msg = "#{EXTENSION.name} requires SketchUp 20#{REQUIRED_SU_VERSION} or later to run."
    UI.messagebox(msg)
    raise msg
  end

  Sketchup.require(File.join(PLUGIN_DIR, "menu"))

  # Reload whole extension (except loader) without littering
  # console. Inspired by ThomTohm's method.
  # Only works before extension has been scrambled.
  #
  # clear_console - Clear console from previous content too (default: false)
  # undo_last     - Undo last operation in model (default: false).
  #
  # Returns nothing.
  def self.reload(clear_console = false, undo_last = false)

    # Hide warnings for already defined constants.
    verbose = $VERBOSE
    $VERBOSE = nil

    Dir.glob(File.join(PLUGIN_DIR, "*.rb")).each { |f| load(f) }
    $VERBOSE = verbose

    # Use a timer to make call to method itself register to console.
    # Otherwise the user cannot use up arrow to repeat command.
    UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

    Sketchup.undo if undo_last

    nil
  end

end
end
