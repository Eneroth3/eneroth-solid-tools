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
#     Limited use to Sketchup Pro.

#Load the normal support files
require "sketchup.rb"
require "extensions.rb"

module Ene_SolidTools

PLUGIN_ROOT = File.dirname(__FILE__).gsub("\\", "/") unless defined?(self::PLUGIN_ROOT)

#Extension
ex = SketchupExtension.new("Eneroth Solid Tools", File.join(PLUGIN_ROOT, "ene_solids/main.rb"))
ex.description = "Solids union, subtract and trim tool. Designed to be more consistent to other Sketchup tools than Sketchup's own solid tools."
ex.version = "1.0.1"
ex.copyright = "Julia Christina (eneroth3) Eneroth 2014"
ex.creator = "Julia Christina (eneroth3) Eneroth"
Sketchup.register_extension ex, true

end#module
