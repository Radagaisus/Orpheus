# Changelog

## 0.6.0

- The `delete()` command is now chainable. It does not execute immediately and doesn't expect to receive a callback function. Use `.delete().exec()` from now on. This change was made to make the API more consistent.

## 0.5.2

- Fixed a bug when responding with several calls to the same dynamic key. Calling the key once will return it directly:

```
User.book_author.get(key: ['1984']).exec()
> {books: 'Orwell'}
```

Calling it several times will return it in a nested object:

```
User
	.book_author.get(key: ['1984'])
	.book_author.get(key: ['asoiaf'])
	.exec()
> 
  {
	  books: {
		  '1984': 'Orwell',
		  'asoiaf': 'GRRM'
	  }
  }
```

The bug in the implementation caused the first result in multiple calls to the same dynamic key to be discarded.


## 0.5.0

- Added a way to send dynamic key arguments as either an array or, if it's one argument, as is. For example, `User('id').yearly_bread(key: [2012]).exec()` as well as `User('id').yearly_bread(key: [2012]).exec()`.

- If multiple values of a dynamic key were requested during one request, the result will be returned as an object, with the generated keys as the object keys, instead of arrays. For example:

```coffee

User('radagaisus')
	.books(key: 'history').smembers()
	.books.key('science').smembers()
	.exec ->
```

Will result in:

```coffee
{
	books: {
		history: ['1776', 'The Devil in the White City']
		science: ['The Selfish Gene']
	}
}
```

Instead of:

```coffee
{
	books: [
		['1776', 'The Devil in the White City'],
		['The Selfish Gene']
	]
}


- Add a new function for all dynamic key models, `key`, that stores and then uses the parameters it was supplied with as the dynamic key arguments for the command. For example:

```coffee
class User extends orpheus
	constructor: ->
		@set 'books', key: (genre) -> "books:#{genre}"

user = orpheus.schema.user

user(user_id)
	.books.key('scifi').add('Hyperion')
	.exec()
```

Might be more convenient than:

```coffee
user(uder_id)
	.books.add('Hyperion', key: 'scifi')
	.exec()
```

- Support for NodeJS 0.10 and above

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
