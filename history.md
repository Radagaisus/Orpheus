# Changelog

## 0.4.0
- Removed the `.del` operation.
- Added the `type`, `ttl`, `pexpire`, `pexpireat`, `pttl`, `persist`, `expireat`, `expire` `exists` and `del` commands for sets, zsets, lists and hashes.

## 0.3.1

- Relationship queries must use `.exec` to execute.

## 0.3.0

- Added the namespace option to `@has 'book', namespace: 'book'`.
- Fixed `Orpheus.schema`, it will now store an object of all the different models functions.


## 0.2.3

- Updated the dependencies for `underscore` and `async`.
- Locked `redis` to `0.8.2`.

## 0.2.2

- Added `llen` to the getters.
- Added an array response to multiple requests on the same property.

## 0.2.1

- added `zcard` to the getters
- Fixed a bug where number fields with 0 as the value would get discarded when getting the model

## 0.2.0

- `zscore`, `zrank`, `count`, `zrevrank`, `zrevrangebyscore` were added to the `getters` array.

- `user_id` is not being passed to `.exec()` for existing models any more. Only new models will receive `user_id` inside `.exec()` as the last argument.

- Everything is now being tested with redis 2.6.

- Added default values for all types, just pass `@str 'name', default: 'John Doe'`.

## 0.1.10

- Removed the @private property. Undocumented `getall` function removed as well. Use customized getters or remove the private properties in your controllers.

- Using `set`, `add` and `del` on undefined attributes will throw an error `"Orpheus :: No Such Model Attribute: #{k}"`.

- a dynamic function for removing relations was added.

- dynamic key functions now work with arguments