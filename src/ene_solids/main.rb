module Eneroth
module SolidTools

  if Sketchup.version.to_i < REQUIRED_SU_VERSION
    msg = "#{EXTENSION.name} requires SketchUp 20#{REQUIRED_SU_VERSION} or later to run."
    UI.messagebox(msg)
    raise msg
  end

  Sketchup.require(File.join(PLUGIN_DIR, "menu"))

  # Reload extension.
  #
  # @param clear_console [Boolean] Whether console should be cleared.
  # @param undo [Boolean] Whether last oration should be undone.
  #
  # @return [Void]
  def self.reload(clear_console = true, undo = false)
    # Hide warnings for already defined constants.
    verbose = $VERBOSE
    $VERBOSE = nil
    Dir.glob(File.join(PLUGIN_DIR, "**/*.{rb,rbe}")).each { |f| load(f) }
    $VERBOSE = verbose

    # Use a timer to make call to method itself register to console.
    # Otherwise the user cannot use up arrow to repeat command.
    UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

    Sketchup.undo if undo

    nil
  end

end
end
