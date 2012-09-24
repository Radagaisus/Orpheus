# Changelog

# 0.1.11

- zscore, zrank and zrevrank added for getting stuff

- removed returning the user_id for existing models.

# 0.1.10

- Removed the @private property. Undocumented `getall` function removed as well. Use customized getters or remove the private properties in your controllers.

- Using `set`, `add` and `del` on undefined attributes will throw an error `"Orpheus :: No Such Model Attribute: #{k}"`.

- a dynamic function for removing relations was added.

- dynamic key functions now work with arguments