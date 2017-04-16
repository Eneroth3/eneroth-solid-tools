# Eneroth Solid Tools

# Copyright Julia Christina Eneroth, eneroth3@gmail.com

require "sketchup.rb"
require "extensions.rb"

module EneSolidTools

  EXTENSION = SketchupExtension.new(
    "Eneroth Solid Tools",
    File.join(File.dirname(__FILE__), File.basename(__FILE__, ".rb"), "main")
  )
  EXTENSION.creator     = "Julia Christina Eneroth"
  EXTENSION.description = 
    "Solid union, subtract and trim tool. Designed to be more consistent to "\
    "other SketchUp tools than SketchUp's native solid tools."
  EXTENSION.version     = "1.1.0"
  EXTENSION.copyright   = "#{EXTENSION.creator} #{Time.now.year}"
  Sketchup.register_extension(EXTENSION, true)

end