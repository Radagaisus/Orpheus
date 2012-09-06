# Orpheus - Redis Little Helper
Orpheus is a Redis Object Model for CoffeeScript.

`npm install orpheus`

**Important**: Right now, afaik, Orpheus is only used by our team. If you are using orpheus please ping me on [Twitter](http://twitter.com/#!/radagaisus) or on [EngineZombie](http://enginezombie.com/), so I will know not to come crashing down and add too many breaking changes. The next release will be the last to appear without a Changelog and will be considered stable.

- Rails like models
- Validations
- Private properties
- simple relations
- transactional spirit, with multi
- Dynamic keys
- Maps between strings and ids

## A Small Taste
```coffee
  class User extends Orpheus
    constructor: ->
      @has 'book'
      
      @str 'about_me'
      @num 'points'
      @zset 'ranking'
      
      @map @str 'fb_id'
      @private @str 'fb_secret'
  
  user = Player.create()
  
  user('modest')
    .add
      about_me: 'I like douchebags and watermelon'
      points: 5
    .books.add('dune','maybe some proust')
    .err (err) ->
      res.json err.toResponse()
    .exec ->
      # woho!
```

## Configuration ##

```coffee
Orpheus.configure
   client: redis.createClient()
   prefix: 'bookapp'
```

Options:

- **client**: the Redis client.
- **prefix**: optional prefix for keys. defaults to `orpheus`.

## Working with the API

### Add, Set

```coffee
user('dune')
  .add
    points: 20
    ranking: [1, 'best book ever!']
  .set
    name: 'sequel'
  .exec()
```

```
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

### Separate Callbacks

Just like with the `multi` command you can supply a separate callback for specific commands.

```coffee
user('mgmt')
  .pokemons.push('pikachu', 'charizard', redis.print)
  .err
    -> # ...
  .exec ->
    # ...
```

### Conditional Commands

Sometimes you'll want to only issue specific commands based on a condition. If you don't want to break the chaining and clutter the code, use `.when(fn)`. `When` executes `fn` immediately, with the context set to the model context. `Only` is an alias for `when`.

```coffee
info = get_mission_critical_information()
player('danny').when( ->
	if info is 'nah, never mind' then @name.set('oh YEAHH')
).points.incrby(5) # Business as usual
.exec()
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
user('chaplin').books.smembers (err, book_ids) ->
  
  # With async functions for fun and profit
  user('chaplin').books.map book_ids, (id, cb, i) ->
      book(id).get cb
    (err, books) ->
      # What? Did we just retrieved all the books from Redis?
```

## Dynamic Keys

```
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
  .err ->
    res.json status: 400
  .exec ->
    res.json status: 200
```

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

## Development ##
### Test ###
`cake test`

### Contribute ###

- `cake dev`
- Add your tests.
- Do your thing.
- `cake dev`

## Roadmap ##

- Validations
- Promises 