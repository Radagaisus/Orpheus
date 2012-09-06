# Changelog

# 0.2.0

- Removed the @private property. Undocumented `getall` function removed as well. Use customized getters or remove the private properties in your controllers.
- Using `set`, `add` and `del` on undefined attributes will throw an error `"Orpheus :: No Such Model Attribute: #{k}"`.
- a dynamic function for removing relations was added.