Menu: [b]Tools > Eneroth Solid Tools[/b].

[b]Union[/b]: Add one solid group or component to another.

[b]Subtract[/b]: Subtract one solid group or component from another.

[b]Trim[/b]: Trim away one solid group or component from another.

If the tools are activated with two or more solids selected, the plugin guesses the biggest one is the primary (the one to keep but modify) and the smaller are the secondary ones, deciding how the primary one is modified.

If tool is activated with no selection you'll be asked to click each solid, first the primary one and then any number of secondary ones used to alter it.

The primary solid will keep its layer, material, attributes and even ruby variables pointing at it unlike how native solid tools work. Layers and attributes of entities inside both of the solids will also be kept.

If the primary solid is a component it will unlike the native solid tools keep being a component and all instances of it will be altered at once, just as components are supposed to behave. If you want to alter only this one instance, first right click it and make it unique as you normally would.

These tools, unlike the native solid tools, completely ignores nested groups and components. You can e.g. easily cut away a part or add something to a building even if it has windows or other details drawn to it, as long as the primitives (faces and edges) inside it form as solid.

Any tool in the plugin be activated and used to check if a group or component is regarded a solid by the plugin, simply by hovering it and see if it gets highlighted.

Change log

  1.0.0 (2014-11-13)
    First Release

   1.0.1 (2014-11-21)
    Limited use to Sketchup Pro (due to EW terms and conditions).

   1.0.2 (2016-07-25)
    Fixed bug in intersecting volumes.
