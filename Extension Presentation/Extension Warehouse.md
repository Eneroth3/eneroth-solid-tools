# Eneroth Solid Tools (Pro Only)

Solid tools designed to feel more native to SketchUp than the native solid
tools.

These tools are designed to modify objects in place, rather than creating new
groups to hold the output. This means all instances of a component can be edited
simultaneously, as components are supposed to behave (and if you don't want
that, just make it unique first).

For this to work all operations have one (or more) target objects to edit, and
any number of modifier objects defining how to edit it. Even union, that
geometrically is symmetrical, has a defined target.

These tools also honor the material inheritance model. If you have painted a
group as a whole with a material, not its individual faces, these tools respect
that. After the operation the target solid retains the same material as it had
prior to the operations, and so do all contained faces.

Layers, hidden state, axes, BIM data and other properties of the target are kept
too. Even variables pointing at the objects stay valid, making these operations
useful in other extensions too.

These tools uses an extended definition of a solid, that ignores nested groups
and components. For instance a group containing a house can be considered solid
even if there are cut-opening door and window components. You can still use the
tools to add or subtract volumes. To check if something is considered solid by
this definition, just activate one of the tools, hover the object and see if it
gets picked up.

Lastly these tools can be used on multiple objects at once. For instance you can
select a whole timber frame along with cladding and trim it using a box to see
into the building.

Menu: *Tools > Eneroth Solid Tools*.

*Union*: Unite solid groups/components to larger ones.

*Subtract*: Subtract solid groups/components.

*Trim*: Trim solid groups/components to other solids.

*Intersect*: Find overlap between solid groups/components.

To use multiple targets in Trim and Subtract, pre-select the targets prior to
activating the tool.

Union and Intersect on the other hand can be instantly used, without activating
the tool, if 2 or more solids are selected before pressing the button.

April 2017 this extension was made open source, [available at GitHub](https://github.com/Eneroth3/Eneroth-Solid-Tools).

## Change Log ##

### 3.0.0 (2018-04-01)###

Added multi target trim and subtract.
Fixed issue with interior holes in faces.
Fixed coplanar faces merging in modifier geometry.
Refactor and code cleaning (makes it easier to maintain the project in the future).

### 2.0.1 (2017-11-05) ###

Use vector icons.
Added Eneroth Tool Memory icon.

### 2.0.0 ###
Made open source.
Added intersect tool.
Fixed toolbar icons not being checked when tool is active.
Additional clicks keeps modifying what is already being modified (use Esc to select new solid to modify).
Allow more than two selected solids to be operated on on tool activation.

### 1.0.2 (2016-07-25) ###
Fixed bug in intersecting volumes.

### 1.0.1 (2014-11-21) ###
Limited use to Sketchup Pro (due to EW terms and conditions).

### 1.0.0 (2014-11-13) ###
First Release
