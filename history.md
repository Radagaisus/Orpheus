# Changelog

# 0.1.11

- `zscore`, `zrank`, `count`, `zrevrank`, `zrevrangebyscore` were added to the `getters` array.

- `user_id` is not being passed to `.exec()` for existing models any more. Only new models will receive `user_id` inside `.exec()` as the last argument.

- Everything is now being tested with redis 2.6.

- Added default values for all types, just pass `@str 'name', default: 'John Doe'`.

# 0.1.10

- Removed the @private property. Undocumented `getall` function removed as well. Use customized getters or remove the private properties in your controllers.

- Using `set`, `add` and `del` on undefined attributes will throw an error `"Orpheus :: No Such Model Attribute: #{k}"`.

- a dynamic function for removing relations was added.

- dynamic key functions now work with arguments