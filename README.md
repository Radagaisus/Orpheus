# Orpheus - Redis Little Helper
Orpheus is a Redis Object Model for CoffeeScript.

- Rails like models
- Validations
- Private properties
- simple relations
- transactional spirit, with multi
- Dynamic keys
- Maps between strings and ids

an npm package will be up soon.

# In Action
```coffee
  # Let's create a couple of models
  class User extends Orpheus
    constructor: ->
      @has 'book'
      
      @zset 'alltime_ranking'
      @str 'about_me'
      
      # one to one map between the id and the fb_id
      @map @str 'fb_id'
      
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
  user('xss-exhibitionist').getall (err, res, id) -> # ...

  # Fun with relations
  # add to the total votes for the book
  # hincrby prefix:bo:catch22 votes 1
  # and to olga's votes for the book
  # hincrby prefix:bo:catch22:us:olga votes 1
  book('catch22').add
    votes: 1
  .user('olga').add
    votes: 1
  .exec -> # ...
  
  # for every relation you get a free set
  book('SICP').users.smembers (err, users) ->
    return next err, false if err
    
    # and a helping hand for getting details
    book('SICP').users.get users, (err, users) ->
      next err, users
  
  # Sweet user authentication with maps
  # (this example uses passportjs)
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
  
  # We all hate configurations
  Orpheus.configure
    client: redis.createClient()
    prefix: 'bookapp'
```

## Planned ##
- `@map` - delete, setnx and minor fixes
- type and cap for lists
- Default validations (for type)
- Validation helpers
- `@json` data type
- Denormalization helpers