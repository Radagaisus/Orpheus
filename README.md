# Orpheus - Redis Little Helper
**version**: pre pre pre 0.1
```coffee
  class Player extends Orpheus
  	constructor: ->
  		@has 'brand'
		
  		@str 'name'
		
  		@num 'points'
		
  		@map @str     'fb_id' # @map not implemented yet
  		@str          'fb_name'
  		@str          'fb_gender'
  		@str          'fb_url'
  		@private @str 'fb_token'
		
  		# Facebook Details
  		@map @str     'fb_id' # @map not implemented yet
  		@str          'fb_name'
  		@str          'fb_gender'
  		@str          'fb_url'
  		@private @str 'fb_token'
		
  		# Twitter Details
  		@str          'twitter_nick'
  		@map @str     'twitter_id'
  		@private @str 'twitter_token'
  		@private @str 'twitter_secret'
  		@num          'twitter_followers'
		
  		# General Stats
  		@str 'rank'
  		@num 'points'
  		@zset 'badges'
  		@list 'activities'
  			type: 'json'
  			cap: 200
		
  		# @json 'something' - Not Implemented
  		@set 'something'
		
  		# Special Keys
  		@zset 'monthly_ranking'
  		  key: ->
  		    d = new Date()
  		    "#{d.getFullYear()}:#{d.getMonth()+1}"
		
  		# Validations
  		@validate 'name', (name) ->
  			if name is 'bill clinton' then true else message: 'Name must be bill clinton!'

  # Adding, Updating, Deleting
  player(13)
  	.badges.zincrby(20, 'almog')
  	.hmset('twitter_nick', 'almog', 'heho', 'boos')
  	.exec (err, res, id) ->
  		# ...
  
  # Alternatively
  player('someplayer')
    .set # set, add, del
      badges: [20, 'almog']
      twitter_nick: 'almog'
      heho: 'boos'
    .exec (err, res, id) -> #...
    

  # Getting Information
  player(15).brand(13).get (err, res, id) -> # ...
  player(15).brand(13).getall (err, res, id) -> #...

  # All errors are logged (but I don't like it)
  Orpheus.errors.get()
  Orpheus.errors.flush()

  Orpheus.errors.subscribe (err) -> # err.message, err.type
	
  # Helper for retrieving model information based on an array
  catalog('fifteen').users.smembers (err, users) ->
  	return done err, null if err
	
  	Orpheus.users.get users, (err, users) ->
  		done err, users
```