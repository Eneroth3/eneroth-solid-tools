# Eneroth Solid Tools

Eneroth Solid tools are designed to be easy to use solid operations that better
fit into SketchUp than SketchUp's native solid tools.

## Differences from native Solid Tools

The key difference is that these operations modify existing group/components
(from now on called containers) in place, rather than outputting the result to a
brand new group. Retaining the original object allows for BIM attributes, axes
placement, material inheritance, layer, references in other extensions and other
properties/aspects to be retained.

This also mean all other instances of the same component are modified as once.
If the user wants to modify only one instance, it is up to the user to
explicitly make that instance unique first. It is not up to the operations to
implicitly make definitions unique without the users knowledge or consent.

These operations also make the material inheritance model remain intact. If the
user has made the decision to keep the default (aka nil) material on all faces
in a container and instead have painted the container as a whole from the
outside, this choice is respected (this is by the way the preferred way to apply
materials in SketchUp as it allows for fast repainting of the object).

Lastly these operators ignore nested containers, whereas the native operators
refuse to regard any container with nested containers as a solid.

## Implementation stuff

Preserving the existing object is made possible by regarding all operations as
asymmetrical (or non communicative). Even the union operation, which
geometrically is symmetrical, is regarded asymmetrical, with one _target_
container being modifier, and one _modifier_ container defining how to perform
the modifications.

## Use in Other Extensions

These operations were originally created for use in other extensions (Eneroth
Townhouse System to be precise) and not be a standalone extension. In time the
solid operations should be split off into its own library (see #2). For now
the solids.rb file have to be ripped out of this extension if it is to be used
elsewhere.

## Project history #

This project was started back in 2014 when I (Eneroth3) was still quite new to
Ruby and programming in general. I worked hard over a few days to clean up,
refactor and style the code to teh state where it could be published.


The project follows [bbatsov's style guide for Ruby](https://github.com/bbatsov/ruby-style-guide).