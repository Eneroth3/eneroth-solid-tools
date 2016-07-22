# Eneroth Solid Tools

# Author: Julia Christina Eneroth, eneroth3@gmail.com

# Usage
#	 Tools > Eneroth Solid Tools or Toolbar
#   Union:    Add one solid group or component to another.
#   Subtract: Subtract one solid group or component from another.
#   Trim:    Trim away one solid group or component from another.
#
# If tools are activated with 2 solids selected, the plugin guesses the biggest
# one is the original (the one to keep but change) and the smallest is the one
# deciding how the original is modified.
#
# The original will keep its layer, material, attributes and even ruby variables
# pointing at it unlike how native solid tools work. Layers and attributes of
# entities inside both of the solids will also be kept.
#
# If you start the tool with no selection you'll be asked to click each solid,
# first the original and then the one used to alter it.
#
# Any of these solid tools can be activated and used to check if a group or
# component is regarded a solid by hovering it and see if it's highlighted.
#
# These tools unlike the native solid tools completely ignores nested groups and
# components so you can for instance easily cut away a part or add something to
# a building even if it has windows or other details drawn to it, as long as the
# raw geometry inside it form as solid.

# Copyright Julia Christina Eneroth (eneroh3)

# Change log
#   1.0.0
#     First Release
#
#   1.0.1
#     Limited use to Sketchup Pro (due to EW terms and conditions).
#
#   2.0.2
#     Fixed bug in intersecting volumes.

require "sketchup.rb"
require "extensions.rb"

module EneSolidTools

  # Public: General extension information.
  AUTHOR      = "Julia Christina Eneroth"
  CONTACT     = "#{AUTHOR} at eneroth3@gmail.com"
  COPYRIGHT   = "#{AUTHOR} #{Time.now.year}"
  DESCRIPTION =
    "Solids union, subtract and trim tool. Designed to be more consistent to "\
    "other Sketchup tools than Sketchup's native solid tools."
  ID          =  File.basename __FILE__, ".rb"
  NAME        = "Eneroth Solid Tools"
  VERSION     = "1.0.2"
  
  # Public: Path to loader file's directory.
  PLUGIN_ROOT = File.expand_path(File.dirname(__FILE__))

  # Public: Path to plugin's own directory.
  PLUGIN_DIR = File.join PLUGIN_ROOT, ID

  # Create Extension once required gems are installed.
  ex = SketchupExtension.new(NAME, File.join(PLUGIN_DIR, "main"))
  ex.description = DESCRIPTION
  ex.version     = VERSION
  ex.copyright   = COPYRIGHT
  ex.creator     = AUTHOR
  Sketchup.register_extension ex, true

end
