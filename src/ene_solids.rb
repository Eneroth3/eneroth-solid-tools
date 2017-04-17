# Eneroth Solid Tools

require "sketchup.rb"
require "extensions.rb"

module EneSolidTools

  EXTENSION_DIR = File.join(File.dirname(__FILE__), File.basename(__FILE__, ".rb"))
  REQUIRED_SU_VERSION = 14

  EXTENSION = SketchupExtension.new(
    "Eneroth Solid Tools",
    File.join(EXTENSION_DIR, "main")
  )
  EXTENSION.creator     = "Julia Christina Eneroth"
  EXTENSION.description =
    "Solid union, subtract and trim tool. Designed to be more consistent to "\
    "other SketchUp tools than SketchUp's native solid tools."
  EXTENSION.version     = "2.0.0"
  EXTENSION.copyright   = "#{EXTENSION.creator} #{Time.now.year}"
  Sketchup.register_extension(EXTENSION, true)

end