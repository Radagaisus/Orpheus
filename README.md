# Orpheus - Redis Little Helper
Orpheus is a Redis Object Model for CoffeeScript.

`npm install orpheus`

[![build status](https://secure.travis-ci.org/Radagaisus/Orpheus.png)](http://travis-ci.org/Radagaisus/Orpheus)

- Rails like models
- Sexy DSL
- simple relations
- transactional spirit, with multi
- Dynamic keys
- Maps between strings and ids
- Validations

## A Small Taste
```coffee
class User extends Orpheus
  constructor: ->
    @has 'book'
    
    @str 'about_me'
    @num 'points'
    @set 'likes'
    @zset 'ranking'
      
    @map @str 'fb_id'
    @str 'fb_secret'
  
User.create()

Orpheus.schema.user('modest')
  .add
    about_me: 'I like douchebags and watermelon'
    points: 5
  .books.add('dune','maybe some proust')
  .err (err) -> res.json err
  .exec ->
      # woho!
```

## Types ##

Orpheus supports all the basic types of Redis: `@num`, `@str`, `@list`, `@set`, `@zset` and `@hash`. Note that strings and numbers are stored inside the model hash. See the wiki for [supported commands and key names for each type](https://github.com/Radagaisus/Orpheus/wiki).

## Configuration ##

```coffee
Orpheus.configure
   client: redis.createClient()
   prefix: 'bookapp'
```

Options:

- **client**: the Redis client.
- **prefix**: optional prefix for keys. defaults to `orpheus`.

## Issuing Commands with Orpheus

### The Straightforward Way

```coffee
  user('rada')
    .name.hset('radagaisus')
    .points.hincrby(5)
    .points_by_time.zincrby(5, new Date().getTime())
    .books.sadd('dune')
```

Note you don't need to add the command prefix in this cases:

```coffee
shorthands:
  str: 'h'
  num: 'h'
  list: 'l'
  set: 's'
  zset: 'z'
  hash: 'h'
```

So the commands above could have been just `set`, `incrby` and `add`.

### Adding, Setting

```coffee
user('dune')
  .add
    points: 20
    ranking: [1, 'best book ever!']
  .set
    name: 'sequel'
  .exec()
```

```coffee
add:
	num:  'hincrby'
	str:  'hset'
	set:  'sadd'
	zset: 'zincrby'
	list: 'lpush'

set:
	num:  'hset'
	str:  'hset'
	set:  'sadd'
	zset: 'zadd'
	list: 'lpush'
```

### Removing the Model

```coffee
user('dune').delete (err, res) ->
```

### Getting Stuff

Getting the entire model in Orpheus is pretty easy:

```coffee
user.get (err, user) ->
  res.json user
```

Specific queries for getting stuff will also convert the response to an object, provided all the commands issued are for getting stuff (no `incrby` or `lpush` somewhere in the query).

```coffee
get_user: (fn) ->
      @name.get()
      @fb_id.get()
      @fb_friends.get()
      @member_since.get()
      @exec fn
```

Converting to object supports this commands:

```coffee
getters: [
  # String, Number
  'hget',
  
  # List
  'lrange',
  'llen',
  
  # Set
  'smembers',
  'scard',
  
  # Zset
  'zrange',
  'zrangebyscore',
  'zrevrange',
  'zrevrangebyscore',
  'zscore',
  'zrank',
  
  # Hash
  'hget',
  'hgetall',
  'hmget'
]
```

Getting stuff while updating stuff in the same query will return the results in an array, the same way a Redis `multi()` command will return the results.

Sometimes you need to do a few operations on the same property, like grabbing a few items off a list and getting the list length. In this case the returned propery will be an array, the first element of which is the response for the first request for that property and so on.

```
user('almog')
  .activities.len()
  .activites.range(0, 3)
  .exec (err, response) ->
    # response might be [20, ['item1', 'item2', 'item3']]
```


### Err and Exec

Orpheus uses the `.err()` function for handling validation and unexpected errors. If `.err()` is not set the `.exec()` command receives errors as the first parameter.

```coffee
user('sonic youth')
  .add
    name: 'modest mouse'
    points: 50
  .err (err) ->
    if err.type is 'validation'
      # phew, it's just a validation error
      res.json err.toResponse()
    else
      # Redis Error, or a horrendous
      # bug in Orpheus
      log "Wake the sysadmins! #{err}"
      res.json status: 500
  .exec (res, id) ->
    # fun!
```

**Without Err**:

```coffee
user('putin')
  .add
    name: 'putout'
  .exec (err, res, id) ->
    # err is the first parameter
    # everything else as usual
```

### Getting the Model ID
When new models are created `.exec()` receives the model ID as the last argument.

```coffee
user()
  .name.set('zappa')
  .exec (err, res, user_id) ->
    user(user_id)
      .name.set('turing')
      .exec()
```


### Separate Callbacks

Just like with the `multi` command you can supply a separate callback for specific commands.

```coffee
user('mgmt')
  .pokemons.push('pikachu', 'charizard', redis.print)
  .name.set('The Machine')
  .exec ->
    # ...
```

### Conditional Commands

Sometimes you'll want to only issue specific commands based on a condition. If you don't want to break the chaining and clutter the code, use `.when(fn)`. `When` executes `fn` immediately, with the context set to the model context. `only` is an alias for `when`.

```coffee
info = get_mission_critical_information()
player('danny').when( ->
	if info is 'nah, never mind' then @name.set('oh YEAHH')
).points.incrby(5) # Business as usual
.exec()
```

### Default Values
Use the `default` option to pass a default value to all types:

```coffee
class User extends Orpheus
  constructor: ->
    @str 'name', default: 'John Doe'

  user = User.create()

  user('nope')
    .name.get()
    .exec (err, res) ->
      log res.name # 'John Doe'
```

Note that default values will be returned in all the get commands of the type. So if you have `{someData: true}` as a default for a zset, you will get that back when you request a `zrank` of a non-existent member:

```
# User Model
@zset 'visits', default: {'/': 0}

# Query
user('rage')
  .visits.rank('/404.html') # No such visit, default is returned
  .exec (err, res) ->
    log res.visits # unexpected default zset value: {'/': 0}
```

### Relations

```coffee
class User extends Orpheus
  constructor: ->
    @has 'book'

class Book extends Orpheus
  constructor: ->
    @has 'user'

user = User.create()
book = Book.create()

# Every relation means a set for that relation
user('chaplin').books.smembers().exec (err, book_ids) ->
  
  # With async functions for fun and profit
  user('chaplin').books.map book_ids, (id, cb, i) ->
      book(id).get cb
    (err, books) ->
      # What? Did we just retrieved all the books from Redis?
```

Your can pass `@has 'book', namespace: 'book'` to create a different namespace than the relation. The default would be `orpheus:us:{user_id}:bo:{book_id}`. By passing the namespace option the key will map to `orpheus:us:{user_id}:book:{book_id}`

## Dynamic Keys

```coffee
class User extends Orpheus
  constructor: ->
    @zset 'monthly_ranking'
      key: ->
        d = new Date()
        # prefix:user:id:ranking:2012:5
        "ranking:#{d.getFullYear()}:#{d.getMonth()+1}"

user = User.create()
user('jackson')
  .monthly_ranking.incrby(1, 'Midnight Oil - The Dead Heart')
  .exec ->
    res.json status: 200
```

Using arguments in dyanmic keys is easy:

```coffee
@zset 'monthly_ranking'
  key: (year, month) ->
    "ranking:#{year || d.getFullYear()}:#{month || d.getMonth()+1}"

# later on, in a far away place...
user('bean')
  .monthly_ranking.incrby(1, 'Stoned Jesus - Im The Mountain', key: [2012, 12])
```

Everything inside `key` will be passed to the dynamic key function.


## One to One Maps

Maps are used to map between a unique attribute of the model and the model ID.

Internally maps use a hash `prefix:users:map:fb_ids`.

This example uses the excellent [PassportJS](passportjs.org).

```coffee
fb_connect = (req, res, next) ->
  fb = req.account
  fb_details =
    fb_id:    fb.id
    fb_name:  fb.displayName
    fb_token: fb.token
    fb_gener: fb.gender
    fb_url:   fb.profileUrl
  
  id = if req.user then req.user.id else fb_id: fb.id
  player id, (err, player, is_new) ->
    next err if err
    # That's it, we just handled autorization,
    # new users and authentication in one go
    player
      .set(fb_details)
      .exec (err, res, user_id) ->
        req.session.passport.user = user_id if user_id
        next err
```

#### What Just Happened?

There are two scenarios:

1. **Authentication**: `req.user` is undefined, so the user is not logged in. We create an object `{fb_id: fb.id}` to use in the map. Orpheus requests `hget prefix:users:map:fb_ids fb_id`. If a match is found we continue as usual. Otherwise a new user is created. In both cases, the user's Facebook information is updated.

2. **Authorization**: `req.user` is defined. The anonymous function is called right away and the user's Facebook information is updated.

## Validations ##

Validations are based on the input, not on the object itself. For example, `hincrby 5` will validate the number 5 itself, not the accumulated value in the object.

Validations run synchronously.

```coffee
class User extends Orpheus
  constructor: ->
    @str 'name'
    @validate 'name', (s) -> if s is 'something' then true else 'name should be "something".'

player = Player.create()
player('james').set
  name: 'james!!!'
.err (err) ->
  if err.type is 'validation'
    log err # <OrpheusValidationErrors>
  else
    # something is wrong with redis
.exec (res) ->
  # Never ever land
```

**OrpheusValidationErrors** has a few convenience functions:

- **add**: adds an error
- **empty**: clears the errors
- **toResponse**: returns a JSON:

```coffee
{
  status: 400, # Bad Request
  errors:
    name: ['name should be "something".']
}
```

`errors` contains the actual error objects:

```coffee
{
  name: [
    msg: 'name should be "something".',
    command: 'hset',
    args: ['james!!!'],
    value: 'james!!!',
    date: 1338936463054 # new Date().getTime()
  ],
  # ...
}
```

### Customizing Message

```coffee
@validate 'legacy_code',
	format: /^[a-zA-Z]+$/
	message: (val) -> "#{val} must be only A-Za-z"
```

Will do the trick. Number validations do not support customized messages yet.

### Custom Validations ###

```coffee
class Player extends Orpheus
	constructor: ->
		@str 'name'
		@validate 'name', (s) -> if s is 'babomb' then true else 'String should be babomb.'
```

### Number Validations ###

```coffee
@num 'points'

@validate 'points',
	numericality:
		only_integer: true
		greater_than: 3
		greater_than_or_equal_to: 3
		equal_to: 3
		less_than_or_equal_to: 3
		odd: true
```

Options:

- **only_integer**: `"#{n} must be an integer."`
- **greater_than**: `"#{a} must be greater than #{b}."`
- **greater_than_or_equal_to**: `"#{a} must be greater than or equal to #{b}."`
- **equal_to**: `"#{a} must be equal to #{b}."`
- **less_than**: `"#{a} must be less than #{b}."`
- **less_than_or_equal_to**: `"#{a} must be less than or equal to #{b}."`
- **odd**: `"#{a} must be odd."`
- **even**: `"#{a} must be even."`

### Exclusion and Inclusion Validations ###

```coffee
@str 'subdomain'
@str 'size'
@validate 'subdomain',
	exclusion: ['www', 'us', 'ca', 'jp']
@validate 'size',
	inclusion: ['small', 'medium', 'large']
```

### Size ###

```coffee
@str 'content'
@validate 'content'
	size:
		tokenizer: (s) -> s.match(/\w+/g).length
		is: 5
		minimum: 5
		maximum: 5
		in: [1,5]
```

Options:

- **minimum**: `"'#{field}' length is #{len}. Must be bigger than #{min}.`
- **maximum**: `"'#{field}' length is #{len}. Must be smaller than #{max}."`
- **in**: `"'#{field}' length is #{len}. Must be between #{range[0]} and #{range[1]}."`
- **is**: `"'#{field}' length is #{len1}. Must be #{len2}."`
- **tokenizer**: useful for splitting the field in different ways. The default is `field.length`.

## Regex Validations ##

```coffee
class Player extends Orpheus
	constructor: ->
		@str 'legacy_code'
		@validate 'legacy_code', format: /^[a-zA-Z]+$/
```

## Error Handling ##

- **Undefined Attributes**: Using `set`, `add` and `del` on undefined attributes will throw an error `"Orpheus :: No Such Model Attribute: #{k}"`. Trying to `no_such_attribute.incrby(1)` will result in `TypeError: Object #<Object> has no method 'incrby'`. The call stack will directly tell you where the misbehaving attribute sits.

## Remove a Relationship ##
A dynamic function, called `"un#{relationship}"()`, is available for removing already declared relationships. For example, a user with a books relationship will have an `unbook()` function available.

This is helpful when trying to abstract away common queries that happen in a lot of requests and denormalize data across relations. Think: points, counters.

```coffee
class User extends Orpheus
      constructor: ->
        @has 'issue'
        @num 'comments'
        @num 'email_replies'

      add_comment: (issue_id) ->
        @comments.incrby 1
        @issue(issue_id)
        @comments.incrby 1
        @unissue()


      add_email_reply: (issue_id, fn) ->
        @add_comment issue_id
        @email_replies.incrby 1
        @issue(issue_id)
        @email_replies.incrby 1
        @exec fn

    user = User.create()
    user('rada').add_email_reply '#142', ->
      # everything went better than expected...
```


## Development ##

- **Test** - Make sure you got [jasmine-node](https://github.com/mhevery/jasmine-node) installed (`npm install jasmine-node -g`) then run `cake test`.

- **Build** - Use `cake bake` to compile the code to JavaScript.
