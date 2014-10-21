Orpheus = require '../lib/orpheus'
redis   = require 'redis'
util    = require 'util'
async   = require 'async'

r = redis.createClient()
monitor = redis.createClient()


# Monitor redis commands
commands = []
monitor.monitor()
monitor.on 'monitor', (time, args) ->
	commands ||= []
	commands.push "#{util.inspect args}"

log = console.log

PREFIX = "orpheus"

# Utility to clean the db
clean_db = (fn) ->
	r.keys "#{PREFIX}*", (err, keys) ->
		if err
			log "problem cleaning test db"
			process.exit 1
		
		for k,i in keys
			r.del keys[i]
		
		fn() if fn

clean_db()

Orpheus.configure
	client: redis.createClient()

afterEach (done) ->
	runs ->
		
		
		# comment out if you don't want to see
		# all the commands
		log ''
		log ''
		log " Test ##{@id+1} Commands - #{@description}"
		log "------------------------"
		for command in commands
			log command
		log "------------------------"
		commands = []
		
		clean_db done


# Error Handling
# -----------------------------------------------------------------------------
describe 'Error Handling', ->
	it 'Throws Error on Undefined Model Attributes', (done) ->
		class User extends Orpheus
			constructor: ->
				@str 'hi'

		try
			User.create()('id').add
					hi: 'hello'
					hello: 'nope'
			.exec()
		catch e
			return done()

		# Fails if it gets here
		expect('To Catch an Error').toBe true
		done()


# Raw Responses
# --------------------------------------------------------------------------
describe 'Raw Responses', ->

	it 'returns a raw response', (done) ->
		class App extends Orpheus
			constructor: ->
				@zset 'leaderboard'

		app = App.create()

		app('test')
		.leaderboard.add(50, 'radagaisus', 20, 'captain')
		.exec ->
			app('test')
			.leaderboard.score('captain')
			.leaderboard.revrank('captain')
			.raw()
			.exec (err, res) ->
				expect(res[0]).toEqual '20'
				expect(res[1]).toEqual 1
				done()


# Schema Specs
# ------------------------------------------------------------------------------
describe 'Schema', ->

	it 'can call the different models using the schema', (done) ->
		class Hello extends Orpheus
			constructor: ->
				@str 'name'

		Hello.create()

		Orpheus.schema.hello('id')
			.name.set('test')
			.exec ->
				r.hget "#{PREFIX}:he:id", 'name', (err, res) ->
					expect(res).toEqual 'test'
					done()



# Redis Commands
# ---------------------------------------
describe 'Redis Commands', ->
	
	it 'Dynamic Keys', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name',
					key: ->
						"oogabooga"
		
		player = Player.create()
		player('hola')
			.name.set('almog')
			.exec ->
				r.hget "#{PREFIX}:pl:hola", 'oogabooga', (err, res) ->
					expect(res).toBe 'almog'
					
					done()
	
	it 'Dynamic Keys Arguments', (done) ->
		class User extends Orpheus
			constructor: ->
				@str 'name',
					key: (var1, var2) ->
						var1 ||= 'hello'
						var2 ||= 'sup'
						"#{var1}:#{var2}"
		user = User.create()

		user('hello')
			.name.set('shalom')
			.exec ->
				r.hget "#{PREFIX}:us:hello", "hello:sup", (err, res) ->
					expect(res).toBe 'shalom'

					user('hiho')
						.name.set('shalom', key: ['what', 'is'])
						.exec ->

							r.hget "#{PREFIX}:us:hiho", "what:is", (err, res) ->
								expect(res).toBe 'shalom'
								done()

	it 'Dynamic key arguments, not in array', (done) ->

		class Test extends Orpheus
			constructor: ->
				@str 'something', key: (actual) -> "test:#{actual}"

		test = Test.create()

		test('hello')
			.something.set('Barış', key: 'yeah')
			.exec ->
				r.hget "#{PREFIX}:te:hello", "test:yeah", (err, res) ->
					expect(res).toBe 'Barış'
					done()

	it 'Dynamic key arguments, using the key function', (done) ->

		class Test extends Orpheus
			constructor: ->
				@str 'something', key: (one, two) -> "#{one}:#{two}"

		test = Test.create()
		
		test('hi')
			.something.key('ha', 'ha').set('boom')
			.exec ->
				r.hget "#{PREFIX}:te:hi", "ha:ha", (err, res) ->
					expect(res).toBe 'boom'
					done()


	it 'Respond properly to multiple requests to get the same dynamic key', (done) ->
		
		class User extends Orpheus
			constructor: ->
				@num 'book_pages',
					key: (book) -> "#{book} pages"
				@num 'leaderboard',
					key: (name) -> "#{name} leaderboard"


		user = User.create()

		user('test')
			.book_pages.set(500, key: ['1984'])
			.book_pages.set(200, key: ['Infinite Jest'])
			.book_pages.set(9999, key: ['A Game of Thrones'])
			.leaderboard.set(100, key: ['Almog'])
			.exec (err, res) ->

				user('test')
				.book_pages.get(key: ['1984'])
				.book_pages.get(key: ['Infinite Jest'])
				.book_pages.get(key: ['A Game of Thrones'])
				.leaderboard.get(key: ['Almog'])
				.exec (err, res) ->
					expect(res.book_pages['1984 pages']).toEqual(500)
					expect(res.book_pages['Infinite Jest pages']).toEqual(200)
					expect(res.book_pages['A Game of Thrones pages']).toEqual(9999)
					expect(res.leaderboard).toEqual(100)

					done()


	it 'Num and Str single commands', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'
		
		player = Player.create()
		
		player('id')
			.name.hset('almog')
			.name.set('almog')
			.points.incrby(5)
			.points.incrby(10)
			.exec (err, res) ->
				expect(err).toBe null
				expect(res.length).toBe 4
				expect(res[0]).toBe 1
				expect(res[1]).toBe 0
				expect(res[2]).toBe 5
				expect(res[3]).toBe 15
		
				r.multi()
				.hget("#{PREFIX}:pl:id", 'name')
				.hget("#{PREFIX}:pl:id", 'points')
				.exec (err, res) ->
					expect(res[0]).toBe 'almog'
					expect(res[1]).toBe '15'
					done()
	
	it 'List Commands', (done) ->
		class Player extends Orpheus
			constructor: ->
				@list 'somelist'
		
		player = Player.create()
		player('id')
			.somelist.push(['almog', 'radagaisus', '13'])
			.somelist.lrange(0, -1)
			.exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 3
				expect(res[1][0]).toBe '13'
			
				done()
	
	it 'Set Commands', (done) ->
		class Player extends Orpheus
			constructor: ->
				@set 'badges'

		player = Player.create()
		player('id')
			.badges.add(['lots', 'of', 'badges'])
			.badges.card()
			.exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 3
				expect(res[0]).toBe 3
				done()
	
	it 'Zset Commands', (done) ->
		class Player extends Orpheus
			constructor: ->
				@zset 'badges'
		
		player = Player.create()
		player('1234')
			.badges.zadd(15, 'woot')
			.badges.zincrby(3, 'woot')
			.exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 1
				expect(res[1]).toBe '18'
				done()
	
	it 'Hash Commands', (done) ->
		class Player extends Orpheus
			constructor: ->
				@hash 'progress'
		
		player = Player.create()
		player('abdul')
			.progress.set('mink', 'fatigue')
			.progress.set('bing', 'sting')
			.exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 1
				expect(res[1]).toBe 1
				
				r.hgetall "#{PREFIX}:pl:abdul:progress", (err, res) ->
					expect(res.mink).toBe 'fatigue'
					expect(res.bing).toBe 'sting'
					done()
	
	it 'Multi Commands with separate callback', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
		player = Player.create()
		player('sam')
			.name.set 'abe', (err, res) ->
				expect(err).toBe null
				expect(res).toBe 1
				done()
			.name.set('greg')
			.exec()
	
	it '#When', (done) ->

		class Player extends Orpheus
			constructor: ->
				@str 'name'
		player = Player.create()
		i = 5
		player('sammy')
			.name.set('hello')
			.when(->
				if i is 6
					@name.set('bent')
			).exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 1
				r.hget "#{PREFIX}:pl:sammy", 'name', (err, res) ->
					expect(res).toBe 'hello'
					
					player('danny').when( ->
						if i is 5
							@name.set('boy')
					).err().exec (res) ->
						expect(res[0]).toBe 1
						done()

	it '#When with a condition as parameter', (done) ->

		class User extends Orpheus
			constructor: ->
				@str 'name'

		user = User.create()

		user('test')
		.name.set('hi')
		.when true, -> @name.set('hello')
		.exec ->
			r.hget "#{PREFIX}:us:test", 'name', (_, res) ->
				expect(res).toBe 'hello'

				user('test2')
				.name.set('hi')
				.when false, ->
					# I have no idea why, but moving this to the same line as the `when`
					# will make the tests hang. BUT, it does work if the condition is true.
					@name.set('hello')
				.exec ->

					r.hget "#{PREFIX}:us:test2", 'name', (_, res) ->
						expect(res).toBe 'hi'

						done()


# Getting Stuff
# ----------------------------------------------
describe 'Get', ->
	it 'Get All', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@str 'name'
				@list 'wins'
				@hash 'progress'
		
		player = Player.create()
		player('someplayer')
			.name
				.set('almog')
			.wins.lpush(['a','b','c'])
			.game('skyrim')
				.name.set('mofasa')
				.progress.set('five', 'to the ten')
				.progress.hmset('six', 'to the mix', 'seven', 'to the heavens')
			.exec ->
				
				player('someplayer').get (err, res) ->
					expect(res.name).toBe 'almog'
					expect(res.wins[0]).toBe 'c'
					
					player('someplayer').game('skyrim').get (err, res) ->
						expect(res.name).toBe 'mofasa'
						expect(res.progress.five).toBe 'to the ten'
						expect(res.progress.six).toBe 'to the mix'
						expect(res.progress.seven).toBe 'to the heavens'
						
						done()
	
	it 'Get Specific Stuff', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'str'
				@num 'num'
				@set 'set1'
				@list 'list'
				@zset 'zset'
				@hash 'hash'
		
		player = Player.create()
		player('15').add
			str: 'str'
			num: 2
			set1: 'set'
			list: 'list'
			zset: [1, 'zset',]
		.hash.set('m', 'd')
		.exec ->
			player('15')
				.str.get()
				.num.get()
				.list.range(0, -1)
				.set1.scard()
				.zset.range(0, -1, 'withscores')
				.err ->
					expect(1).toBe 2
				.exec (res) ->
					log res
					expect(res.str).toBe 'str'
					expect(res.num).toBe 2
					expect(res.set1).toBe 1
					expect(res.list[0]).toBe 'list'
					expect(res.zset.zset).toBe 1
					
					done()

	# Sometimes we want to get differnt kinds of information
	# on the same object. For example, you might want to
	# know a list's length and grab the first few items from
	# it, or you want to zcount a zset. In this case, when
	# you request a few operations on the same element, you
	# will recevie the results inside a property of that
	# object called `results`.
	it 'Getting information on the same element', (done) ->
		class User extends Orpheus
			constructor: ->
				@list 'activities'
				@zset 'points'
				@str  'name'

		user = User.create()

		async.series

				# Create the user data
				create_user: (cb) ->
					user('feist')
					.name.set('feist')
					.activities.push(['activity1', 'activity2', 'activity3', 'activity4'])
					.points.add(10, 'stuff1', 20, 'stuff2', 30, 'stuff3', 45, 'stuff4')
					.exec(cb)

				# Grab information, and make sure the format is good
				get_user: (cb) ->
					user('feist')
						.name.get()
						.activities.llen()
						.activities.lrange(0, -1)
						.points.count(0, 21)
						.points.count(0, 45)
						.points.zrange(0, -1, 'withscores')
						.points.card()
						.exec (err, user) ->
							if err then cb(err)
							else
								expect(user.name).toEqual 'feist'
								expect(user.activities[0]).toEqual 4
								for i,j in ['activity4', 'activity3', 'activity2', 'activity1']
									expect(user.activities[1][j]).toEqual i
								expect(user.points[0]).toEqual 2
								expect(user.points[1]).toEqual 4
								expect(user.points[2]).toEqual 
									stuff1: 10
									stuff2: 20
									stuff3: 30
									stuff4: 45
								expect(user.points[3]).toEqual 4

								cb(undefined, user)

			# Final callback, making sure we got everything right
			, (err, results) ->
				expect(err).toBeNull()
				done()


	it 'Use #as to change the returned key name', (done) ->
		# Define the User model, with only one field - a `name` string
		class User extends Orpheus
			constructor: ->
				@str 'name'
		# Create the user
		user = User.create()
		# Set the user name
		user('test-user').name.set('test-name').exec ->
			# Retrieve the user name as `first_name`
			user('test-user').name.as('first_name').get().exec (err, res) ->
				# Verify we got it in the right key name
				expect(res.first_name).toEqual 'test-name'
				# Verify we didn't get it in the wrong key name
				expect(res.name).toBeUndefined()
				# We're done
				done()


	it 'Use #as to change the returned key name, with nesting', (done) ->
		# Define the User model, with only one field - a `name` string
		class User extends Orpheus
			constructor: ->
				@str 'name'
		# Create the user
		user = User.create()
		# Set the user name
		user('test-user').name.set('test-name').exec ->
			# Retrieve the user name as `first_name`
			user('test-user').name.as('name.first').get().exec (err, res) ->
				# Verify we got it in the right key name
				expect(res.name.first).toEqual 'test-name'
				# And that `res.name` is now an object
				expect(typeof res.name).toEqual 'object'
				# We're done
				done()


# Setting Stuff
# --------------------------------------------
describe 'Setting Records', ->
	
	it 'Setting Strings', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@str 'favourite_color'
				@str 'best_movie'
				@str 'wassum'

		player = Player.create()
		player('15').set
			name: 'benga'
			wassum: 'finger'
			best_movie: 5
			favourite_color: 'stingy'
		.exec (err, res, id) ->
			expect(err).toBe null

			r.hgetall "#{PREFIX}:pl:15", (err, res) ->
				expect(err).toBe null
				expect(res.name).toBe 'benga'
				expect(res.wassum).toBe 'finger'
				expect(res.best_movie).toBe '5'
				expect(res.favourite_color).toBe 'stingy'
	
				done()
	
	it 'Setting Numbers', (done) ->
		class Player extends Orpheus
			constructor: ->
				@num 'bingo'
				@num 'mexico'
				@num 'points'
				@num 'nicaragua'

		player = Player.create()
		player().set
			bingo: 5
			mexico: 7
			points: 15
			nicaragua: 234345
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null

			r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
				expect(err).toBe null
				expect(res.bingo).toBe '5'
				expect(res.mexico).toBe '7'
				expect(res.points).toBe '15'
				expect(res.nicaragua).toBe '234345'
				done()
	
	it 'Setting Lists with a string', (done) ->
		class Player extends Orpheus
			constructor: ->
				@list 'activities',
					type: 'str'

		player = Player.create()
		player().set
			activities: 'bingo'
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null

			r.lrange "#{PREFIX}:pl:#{id}:activities", 0, -1, (err, res) ->
				expect(err).toBe null
				expect(res.length).toBe 1
				expect(res[0]).toBe 'bingo'
				done()

	it 'Setting Lists with Array', (done) ->
		class Player extends Orpheus
			constructor: ->
				@list 'activities',
					type: 'str'

		player = Player.create()
		player().set
			activities: ['bingo', 'mingo', 'lingo']
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null

			r.lrange "#{PREFIX}:pl:#{id}:activities", 0, -1, (err, res) ->
				expect(err).toBe null
				expect(res.length).toBe 3
				expect(res[0]).toBe 'lingo'
				expect(res[1]).toBe 'mingo'
				expect(res[2]).toBe 'bingo'
				done()
	
	it 'Setting Sets with String', (done) ->
		class Player extends Orpheus
			constructor: ->
				@set 'badges'
		player = Player.create()
		player(15).set
			badges: 'badge'
		.exec (err, res) ->
			expect(err).toBe null

			r.smembers "#{PREFIX}:pl:15:badges", (err, res) ->
				expect(res[0]).toBe 'badge'
				done()

	it 'Setting Sets with Array', (done) ->
		class Player extends Orpheus
			constructor: ->
				@set 'badges'
		player = Player.create()
		player(15).set
			badges: ['badge1', 'badge2', 'badge3', 'badge3']
		.exec (err, res) ->
			expect(err).toBe null

			r.smembers "#{PREFIX}:pl:15:badges", (err, res) ->
				expect(res).not.toBe null
				expect(res.length).toBe 3
				expect(res).toContain 'badge1'
				expect(res).toContain 'badge2'
				expect(res).toContain 'badge3'
				done()
	
	it 'Setting Zsets', (done) ->
		class Player extends Orpheus
			constructor: ->
				@zset 'badges'

		player = Player.create()
		player(2222).set
			badges: [5, 'badge1']
		.set
			badges: [10, 'badge2']
		.set
			badges: [7, 'badge3']
		.exec (err, id) ->

			expect(err).toBe null

			r.zrange "#{PREFIX}:pl:2222:badges", 0, -1, 'withscores', (err, res) ->
				expect(err).toBe null
				success = [ 'badge1', '5', 'badge3', '7', 'badge2', '10' ]
				for f ,i in res
					expect(f).toBe(success[i])
				
				done()


# Adding Stuff
# --------------------------------------------------
describe 'Adding to Records', ->
	
	it 'Should add strings in a record', (done) ->
		
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@str 'favourite_color'
				@str 'best_movie'
				@str 'wassum'

		player = Player.create()
		player().add
			name: 'benga'
			wassum: 'finger'
			best_movie: 5
			favourite_color: 'stingy'
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null
			
			r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
				expect(err).toBe null
				expect(res.name).toBe 'benga'
				expect(res.wassum).toBe 'finger'
				expect(res.best_movie).toBe '5'
				expect(res.favourite_color).toBe 'stingy'

				done()

	it 'Should add numbers in a record', (done) ->
		class Player extends Orpheus
			constructor: ->
				@num 'bingo'
				@num 'mexico'
				@num 'points'
				@num 'nicaragua'

		player = Player.create()
		player().add
			bingo: 5
			mexico: 7
			points: 15
			nicaragua: 234345
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null
			
			r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
				expect(err).toBe null
				expect(res.bingo).toBe '5'
				expect(res.mexico).toBe '7'
				expect(res.points).toBe '15'
				expect(res.nicaragua).toBe '234345'
				_id = id
				player(id).add
					bingo: 45
					mexico: 63
					points: 10
					nicaragua: 1
				.exec (err, res, id) ->
					expect(err).toBe null
					expect(id).toBeUndefined()

					r.hgetall "#{PREFIX}:pl:#{_id}", (err, res) ->
						expect(err).toBe null
						expect(res.bingo).toBe '50'
						expect(res.mexico).toBe '70'
						expect(res.points).toBe '25'
						expect(res.nicaragua).toBe '234346'

						done()

	it 'Should add lists in a record (with an array)', (done) ->
		class Player extends Orpheus
			constructor: ->
				@list 'activities',
					type: 'str'

		player = Player.create()
		player().add
			activities: ['bingo', 'mingo', 'lingo']
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null

			r.lrange "#{PREFIX}:pl:#{id}:activities", 0, -1, (err, res) ->
				expect(err).toBe null
				expect(res.length).toBe 3
				expect(res[0]).toBe 'lingo'
				expect(res[1]).toBe 'mingo'
				expect(res[2]).toBe 'bingo'
				done()


# Substracting Stuff
# -----------------------------------------------
describe 'Substracting from Records', ->

	it 'Should decerment numbers in a record, using add', (done) ->
		class Player extends Orpheus
			constructor: ->
				@num 'bingo'
				@num 'mexico'
				@num 'points'
				@num 'nicaragua'

		player = Player.create()
		player().add
			bingo: 5
			mexico: 7
			points: 15
			nicaragua: 234345
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).not.toBe null

			r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
				expect(err).toBe null
				expect(res.bingo).toBe '5'
				expect(res.mexico).toBe '7'
				expect(res.points).toBe '15'
				expect(res.nicaragua).toBe '234345'
				
				player(id).add
					bingo: -1
					mexico: -2
					points: -3
					nicaragua: -4
				.exec (err, res, _id) ->
					expect(err).toBe null
					expect(_id).toBeUndefined()
					
					r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
						expect(err).toBe null
						expect(res.bingo).toBe '4'
						expect(res.mexico).toBe '5'
						expect(res.points).toBe '12'
						expect(res.nicaragua).toBe '234341'
						
						done()


# Deleting Stuff
# ---------------------------------------
describe 'Delete', ->
	
	it 'Remove Everything', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'bingo'
				@list 'stream'
				@zset 'bonga'
				@hash 'bonanza'
				
		player = Player.create()
		player('id').set
				bingo: 'pinaaa'
				stream: [1,2,3,4,43,53,45,345,345]
				bonga: [5, 'donga']
			.bonanza.set('klingon', 'we hate them')
			.exec ->
				player('id').delete().exec (err, res, id) ->
					expect(err).toBe null
					expect(id).toBeUndefined()
					
					r.multi()
						.exists("#{PREFIX}:pl:id")
						.exists("#{PREFIX}:pl:id:stream")
						.exists("#{PREFIX}:pl:id:bonga")
						.exists("#{PREFIX}:pl:id:bonanza")
						.exec (err, res) ->
							expect(res[0]).toBe 0
							expect(res[1]).toBe 0
							expect(res[2]).toBe 0
							expect(res[3]).toBe 0
							
							done()

	it 'Deletes specific model attributes', (done) ->
		class User extends Orpheus
			constructor: ->
				@num 'points'
				@list 'things'

		user = User.create()
		user('someone')
			.points.set(10)
			.things.push(1, 2, 3, 4)
			.exec ->
				r.hgetall "#{PREFIX}:us:someone", (err, res) ->
					expect(res.points).toEqual '10'

					# Delete the keys
					user('someone')
						.points.del()
						.exec ->
							r.exists "#{PREFIX}:us:someone", (err, res) ->
								expect(res).toEqual 0

								user('someone').things.del().exec ->
									r.exists "#{PREFIX}:us:someone:things", (err, res) ->
										expect(res).toEqual 0
										done()


# Validations
# ------------------------------------------------
describe 'Validation', ->
	it 'Validate Types', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'
		player = Player.create()
		player('sonic').add
			name:   15   # This will work
			points: '20' # This will work
		.err ->
			expect(1).toBe 2
			done()
		.exec ->
			player('sonic').add
				name: ['sonic youth'] # This will not work
				points: '20a'         # This will not work
			.err (err) ->
				expect(err.type).toBe 'validation'
				expect(err.toResponse().errors.name[0]).toBe 'Could not convert name to string'
				expect(err.toResponse().errors.points[0]).toBe 'Malformed number'
				done()
			.exec ->
				expect(3).toBe 4
				done()


	it 'Validate Strings', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@validate 'name', (s) -> if s is 'almog' then true else 'String should be almog'

		player = Player.create()
		player('15').set
			name: 'almog'
		.exec (err, res, id) ->
			expect(res[0]).toBe 1

			player('15').set
				name: 'chiko'
			.err (res) ->
				expect(res.type).toBe 'validation'
				expect(res.valid()).toBe false
				expect(res.toResponse().status).toBe 400
				expect(res.toResponse().errors.name[0]).toBe 'String should be almog'
				expect(res.errors.name[0].msg).toBe 'String should be almog'
				done()
			.exec (err, res, id) ->
				expect(1).toBe 2 # Impossible!
				done()

	it 'Validates Format', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'legacy_code'
				@validate 'legacy_code',
					format: /^[a-zA-Z]+$/
					message: (val) -> "#{val} must be only A-Za-z"
		player = Player.create()
		player('ido').add
			legacy_code: 'sdfsd234'
		.err (err) ->
			expect(err.toResponse().errors.legacy_code[0]).toBe 'sdfsd234 must be only A-Za-z'

			player('mint').add
				legacy_code: 'hello'
			.err (err) ->
				expect(3).toBe 4
				done()
			.exec (res) ->
				expect(res[0]).toBe 1
				done()
		.exec ->
			expect(1).toBe 2
			done()

	it 'Validates Size', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@validate 'name',
					size:
						minimum: 2

				@str 'bio'
				@validate 'bio',
					size:
						maximum: 5

				@str 'password'
				@validate 'password',
					size:
						in: [6,25]

				@str 'registration_number'
				@validate 'registration_number',
					size:
						is: 6

				@str 'content'
				@validate 'content',
					size:
						tokenizer: (s) -> s.match(/\w+/g).length
						is: 5

		player = Player.create()
		player('tyrion').add
			name: 'clear'
			bio: 'beep'
			password: 'Wraith Pinned to the Mist'
			registration_number: 'sixsix'
			content: 'five words yeah five words'
		.err (err) ->
			log err.errors
			expect(1).toBe 2
			done()
		.exec (res) ->
			expect(res[0]).toBe 1
			expect(res[1]).toBe 1
			expect(res[2]).toBe 1
			expect(res[3]).toBe 1
			expect(res[4]).toBe 1

			player('beirut').add
				name: 'i'
				bio: 'long stuff is long'
				password: 'no'
				registration_number: 'haha'
				content: 'four words it is'
			.err (err) ->
				expect(err.toResponse().errors.name[0]).toBe "'i' length is 1. Must be bigger than 2."
				expect(err.toResponse().errors.bio[0]).toBe "'long stuff is long' length is 18. Must be smaller than 5."
				expect(err.toResponse().errors.password[0]).toBe "'no' length is 2. Must be between 6 and 25."
				expect(err.toResponse().errors.registration_number[0]).toBe "'haha' length is 4. Must be 6."
				expect(err.toResponse().errors.content[0]).toBe "'four words it is' length is 4. Must be 5."

				done()
			.exec ->
				expect(3).toBe 4
				done()

	it 'Validate Exclusion & Inclusion', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'subdomain'
				@str 'size'
				@validate 'subdomain',
					exclusion: ['www', 'us', 'ca', 'jp']
				@validate 'size',
					inclusion: ['small', 'medium', 'large']

		player = Player.create()
		player('james').add
			subdomain: 'co'
			size: 'small'
		.err (err) ->
			expect(1).toBe 2
			done()
		.exec (res) ->
			expect(res[0]).toBe 1
			expect(res[1]).toBe 1

			player('mames').add
				subdomain: 'us'
				size: 'penis'
			.err (err) ->
				expect(err.toResponse().errors.subdomain[0]).toBe "us is reserved."
				expect(err.toResponse().errors.size[0]).toBe "penis is not included in the list."
				done()
			.exec (res) ->
				expect(1).toBe 2
				done()

	it 'Validate Numbers', (done) ->
		class Player extends Orpheus
			constructor: ->
				@num 'points'
				@num 'games_played'
				@num 'games_won'

				@validate 'points',
					numericality:
						only_integer: true

				@validate 'games_played',
					numericality:
						only_integer: true
						greater_than: 3
						less_than:    7
						odd:          true

				@validate 'games_won',
					numericality:
						only_integer:             true
						greater_than_or_equal_to: 10
						equal_to:                 10
						less_than_or_equal_to:    10
						even:                     true

		player = Player.create()
		player('id').add
			points: 20
			games_played: 5
			games_won: 10
		.err (err) ->
			expect(1).toBe 2
			done()
		.exec (res) ->
			expect(res[0]).toBe 20
			expect(res[1]).toBe 5
			expect(res[2]).toBe 10

			player('idz').add
				points: 50.5
				games_played: 10
				games_won: 11
			.err (err) ->
				expect(err.toResponse().errors.points[0]).toBe '50.5 must be an integer.'
				expect(err.toResponse().errors.games_played[0]).toBe '10 must be less than 7.'
				expect(err.toResponse().errors.games_won[0]).toBe '11 must be equal to 10.'

				player('nigz').add
					points: 20
					games_played: 5
					games_won: 10.1
				.err (err) ->
					expect(err.toResponse().errors.games_won[0]).toBe '10.1 must be an integer.'
					expect(err.toResponse().errors.games_won[1]).toBe '10.1 must be equal to 10.'
					done()
				.exec (res) ->
					expect(1).toBe 2
					done()
			.exec (res) ->
				expect(1).toBe 2
				done()


# Maps
# ---------------------------------------
describe 'Maps', ->
	it 'Should create a record if @map on a @str did not find a record', (done) ->
		class Player extends Orpheus
			constructor: ->
				@map @str 'name'
				@str 'color'
			
		player = Player.create()
		player name: 'rada', (err, player, player_id, new_player) ->
			expect(err).toBe null
			expect(new_player).toBe true
			
			player.set
				color: 'red'
			.exec (err, res, id) ->
				expect(id).toBe player.id
				expect(err).toBe null
				expect(res[0]).toBe 1
				
				r.hget "#{PREFIX}:players:map:names", 'rada', (err, res) ->
					expect(res).toBe id
					done()
					
	it 'Should find a record based on a @map-ed @str', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'brand'
				
				@map @str 'name'
				@str 'color'
		
		player = Player.create()
		player().set
			name: 'almog'
			color: 'blue'
		.exec (err, res) ->
			player name: 'almog', (err, player, player_id, new_player) ->
				expect(new_player).toBe false
				
				player.set
					color: 'pink'
				.exec (err, res) ->
					expect(res[0]).toBe 0
					done()


# Relations
# ------------------------------
describe 'Relations', ->
	
	it 'handles getting and setting', (done) ->
		class User extends Orpheus
			constructor: ->
				@has 'thing'
				@str 'name'

		class Thing extends Orpheus
			constructor: ->
				@has 'user'
				@str 'name'


		thing = Thing.create()
		user = User.create()

		user('someuser')
			.things.sadd('34234')
			.things.scard()
			.exec (err, res) ->
				expect(err).toBeNull()
				expect(res[0]).toEqual 1
				expect(res[1]).toEqual 1
				done()

				thing('something')
					.users.sadd('555')
					.users.scard()
					.exec (err, res) ->
						expect(err).toBeNull()
						expect(res[0]).toEqual(1)
						expect(res[1]).toEqual(1)

	it 'One has', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@str 'name'

		player = Player.create()
		player('someplayer')
			.name.set('almog')
			.game('skyrim')
			.name.set('mofasa')
			.exec (err, res) ->
				expect(err).toBe null
				expect(res[0]).toBe 1
				expect(res[1]).toBe 1

				r.multi()
					.hget("#{PREFIX}:pl:someplayer", 'name')
					.hget("#{PREFIX}:pl:someplayer:ga:skyrim", 'name')
					.exec (err, res) ->
						expect(res[0]).toBe 'almog'
						expect(res[1]).toBe 'mofasa'
						done()		
	
	it 'Each', (done) ->
		
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@str 'name'

		class Game extends Orpheus
			constructor: ->
				@has 'player'
		
		game = Game.create()
		player = Player.create()
		game('diablo').players.sadd('15', '16', '17').exec ->
			player('15').name.set('almog').exec ->
				player('16').name.set('almog').exec ->
					player('17').name.set('almog').exec ->
						
						game('diablo').players.smembers().exec (err, players) ->
							expect(err).toBe null
							game('diablo').players.map players, (id, c, i) ->
									c(null, {id: id, i: i})
								, (err, players) ->
									expect(err).toBeUndefined()
									for p,i in players
										expect(p.i).toBe i
										expect(p.id).toBe ''+(15+i)
									done()

	it 'Removes a Relationship', (done) ->
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
			done()


	it 'Can work with a different namespace', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game', namespace: 'blob'
				@str 'name'

		player = Player.create()
		player('someplayer')
			.name.set('hello')
			.game('skyrim')
			.name.set('hobbit')
			.exec (err, res) ->
				expect(err).toBeNull()
				expect(res[0]).toBe 1
				expect(res[1]).toBe 1

				r.multi()
					.hget("#{PREFIX}:pl:someplayer", 'name')
					.hget("#{PREFIX}:pl:someplayer:ga:skyrim", 'name')
					.hget("#{PREFIX}:pl:someplayer:blob:skyrim", 'name')
					.exec (err, res) ->
						expect(res[0]).toEqual 'hello'
						expect(res[1]).toBeNull()
						expect(res[2]).toEqual 'hobbit'
						done()



# Defaults
# ------------------------------
describe 'Defaults', ->

	it 'Returns a default value', (done) ->
		class User extends Orpheus
			constructor: ->
				@str 'name', default: 'John Doe'
				@num 'points', default: 0
				@hash 'reviews', default:
					no_reviews: null
				@list 'activities', default: []
				@set 'experience', default: []
				@zset 'troll', default: 'trololol'
				@str 'sup'

		user = User.create()

		user('john')
			.get (err, res) ->
				expect(res.name).toBe 'John Doe'
				expect(res.points).toBe 0
				expect(res.reviews.no_reviews).toBe null
				expect(res.activities.length).toBe 0
				expect(res.experience.length).toBe 0
				expect(res.troll).toBe 'trololol'
				expect(res.sup).toBeUndefined() # No default
				done()


# Ability to connect multiple actions into one atomic multi call
# -----------------------------------------------------------------
describe 'Connect', ->

	it 'Connects commands from two operations, using an object', (done) ->
		
		class User extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'

		class App extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'

		user = User.create()
		app = App.create()

		Orpheus.connect

			user:
				user('some-user')
					.points.set(200)
					.name.set('Snir')

			app:
				app('some-app')
					.points.set(1000)
					.name.set('Super App')

		, (err, res) ->
			expect(err).toBe null
			expect(res.user[0]).toEqual 1
			expect(res.user[1]).toEqual 1
			expect(res.app[0]).toEqual 1
			expect(res.app[1]).toEqual 1

			done()


	it 'Connects commands from two operations, using an array', (done) ->
		
		class User extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'

		class App extends Orpheus
			constructor: ->
				@str 'name'
				@num 'points'

		user = User.create()
		app = App.create()

		Orpheus.connect [
				user('some-user')
				.points.set(200)
				.name.set('Snir')
			,
				app('some-app')
					.points.set(1000)
					.name.set('Super App')
		], (err, res) ->
			expect(err).toBe null
			expect(res[0][0]).toEqual 1
			expect(res[0][1]).toEqual 1
			expect(res[1][0]).toEqual 1
			expect(res[1][1]).toEqual 1

			done()



# Bugs & Regressions
# ---------------------------------------
describe 'Regressions', ->
	
	it 'Returns an object with a number field with 0 as the value', (done) ->
		class User extends Orpheus
			constructor: ->
				@num 'points'

		user = User.create()
		user('zero')
		.points.set(0)
		.exec ->
			user('zero')
			.points.get()
			.exec (err, res) ->
				expect(res.points).toBe(0)

				# User with no points set whatsoever
				user('hi')
				.points.get()
				.exec (err, res) ->
					expect(res.points).toBe(0)
					done()
