# Orpheus - Redis Little Helper
Orpheus is a Redis Object Model for CoffeeScript.

- Rails like models
- Validations
- Private properties
- simple relations
- transactional spirit, with multi
- Dynamic keys

Expect v0.1 to be out soon.

# In Action
```coffee
  # Let's create a couple of models
  class User extends Orpheus
    constructor: ->
      @has 'book'
      
      @str 'fb_name'
      @zset 'alltime_ranking'
      @str 'about_me'
      
      # Private Keys
      @private @str 'fb_secret'
      
      # Dynamic Keys
      @zset 'monthly_ranking'
        key: ->
          d = new Date()
          "ranking:#{d.getFullYear()}:#{d.getMonth()+1}"
  
  class Book extends Orpheus
    constructor: ->
      @has 'user'
      @str 'name'
      @num 'votes'
      @list 'reviews'
      @set 'authors'
      
      # Validations
      @validate 'votes', (vote) ->
        if 0 <= vote <= 10
          true
        else
          message: "Vote isn't between 0 and 10"
  
  # Instantiate them
  user = Player.create()
  book = Book.create()
  
  # Add information in a boring way
  book('dune')
    .votes.incrby(6)
    .reviews.push('it sucked', 'it was awesome')
    .authors.smembers()
    .exec (err, res, id) ->
      # ...
  
  # Or in a fun way
  book('dune').add
    votes:  6
    reviews: ['it sucked', 'it was awesome']
  .authors.smembers()
  .exec (err, res, id) ->
    # ...
  
  # Get information, without private properties
  user('olga').get (err, res, id) -> #...
  
  # Get all the information
  user('xss-exhibitionist').get (err, res, id) -> # ...

  # Fun with relations
  # add to the total votes for the book
  # and to olga's votes for the book
  # hincrby prefix:bo:catch22 votes 1
  # hincrby prefix:bo:catch22:us:olga votes 1
  # respectively
  book('catch22').set
    votes: 1
  .user('olga').set
    votes: 1
  
  # for every relation you get a free set
  book('SICP').users.smembers (err, users) ->
    return next err, false if err
    
    # and a helping hand for getting details
    book('SICP').users.get users, (err, users) ->
      next err, users
  
  # We all hate configurations
  Orpheus.configure
    client: redis.createClient()
    prefix: 'bookapp'

## Planned ##
- `@map`
- type and cap for lists
- Default validations (for type)
- Validation helpers
- `@json` data type
- Denormalization helpers