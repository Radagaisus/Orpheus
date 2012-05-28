Orpheus = require '../lib/orpheus'
redis = require 'redis'
util = require 'util'

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
			process.exit
		
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
	
	it 'List commands', (done) ->
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
	
	it 'Set commands', (done) ->
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
	
	it 'Zset commands', (done) ->
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

describe 'Get Stuff', ->
	it 'Get All', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@str 'name'
				@list 'wins'
		
		player = Player.create()
		player('someplayer')
			.name
				.set('almog')
			.wins.lpush(['a','b','c'])
			.game('skyrim')
				.name
					.set('mofasa')
			.exec ->
				done()
				
				player('someplayer').getall (err, res) ->
					expect(res.name).toBe 'almog'
					expect(res.wins[0]).toBe 'c'
					
					player('someplayer').game('skyrim').getall (err, res) ->
						expect(res.name).toBe 'mofasa'
						done()
						
						
	it 'Get without private', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@private @str 'name'
				@list 'wins'
				@str 'hoho'

		player = Player.create()
		player('someplayer')
			.name.set('almog')
			.wins.lpush(['a','b','c'])
			.game('skyrim')
				.name.set('mofasa')
				.hoho.set('woo')
			.exec ->
				player('someplayer').get (err, res) ->
					expect(res.name).toBeUndefined()
					expect(res.wins[0]).toBe 'c'
					
					player('someplayer').game('skyrim').get (err, res) ->
						expect(res.name).toBeUndefined()
						expect(res.hoho).toBe 'woo'
						done()

describe 'Relations', ->
	
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
	
	it 'Should get relation information', (done) ->
		class Player extends Orpheus
			constructor: ->
				@has 'game'
				@str 'name'
		
		class Game extends Orpheus
			constructor: ->
				@has 'player'
		
		game = Game.create()
		player = Player.create()
		game('diablo').players.sadd '15', '16', '17', ->
			player('15').name.set('almog').exec ->
				player('16').name.set('almog').exec ->
					player('17').name.set('almog').exec ->
						
						game('diablo').players.smembers (err, players) ->
							expect(err).toBe null
							
							game('diablo').players.get players, (err, players) ->
								expect(err).toBeUndefined()
								expect(players.length).toBe 3
								
								for p,i in players
									expect(p.name).toBe 'almog'
									expect(p.id).toBe ''+ (15 + i)
								
								done()

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
			expect(id).not.toBe null

			r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
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
				@list 'activities'
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
				@list 'activities'
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
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).toBe 15

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
		.exec (err, res, id) ->
			expect(err).toBe null
			expect(id).toBe 15

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

				player(id).add
					bingo: 45
					mexico: 63
					points: 10
					nicaragua: 1
				.exec (err, res, id) ->
					expect(err).toBe null
					expect(id).not.toBe null

					r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
						expect(err).toBe null
						expect(res.bingo).toBe '50'
						expect(res.mexico).toBe '70'
						expect(res.points).toBe '25'
						expect(res.nicaragua).toBe '234346'

				done()

	it 'Should add lists in a record (with an array)', (done) ->
		class Player extends Orpheus
			constructor: ->
				@list 'activities'
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
				.exec (err, res, id) ->
					expect(err).toBe null
					expect(id).not.toBe null
					
					r.hgetall "#{PREFIX}:pl:#{id}", (err, res) ->
						expect(err).toBe null
						expect(res.bingo).toBe '4'
						expect(res.mexico).toBe '5'
						expect(res.points).toBe '12'
						expect(res.nicaragua).toBe '234341'
						
						done()

describe 'Delete', ->
	
	it 'Remove Everything', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'bingo'
				@list 'stream'
				@zset 'bonga'
		player = Player.create()
		player('id').set
				bingo: 'pinaaa'
				stream: [1,2,3,4,43,53,45,345,345]
				bonga: [5, 'donga']
			.exec ->
				player('id').delete (err, res, id) ->
					expect(err).toBe null
					expect(id).toBe 'id'
					
					r.multi()
						.exists("#{PREFIX}:pl:id")
						.exists("#{PREFIX}:pl:id:stream")
						.exists("#{PREFIX}:pl:id:bonga")
						.exec (err, res) ->
							expect(res[0]).toBe 0
							expect(res[1]).toBe 0
							expect(res[2]).toBe 0
							
							done()

describe 'Validation', ->
	
	it 'Validate Strings', (done) ->
		class Player extends Orpheus
			constructor: ->
				@str 'name'
				@validate 'name', (s) -> if s is 'almog' then true else message: 'String should be almog'
		
		player = Player.create()
		player('15').set
			name: 'almog'
		.exec (err, res, id) ->
			expect(res[0]).toBe 1
			
			player('15').set
				name: 'chiko'
			.exec (err, res, id) ->
				
				expect(err[0].type).toBe 'validation'
				expect(err[0].toString()).toBe 'Error: String should be almog'
				
				
				done()

describe 'Maps', ->
	it 'Should create a record if @map on a @str did not find a record', (done) ->
		class Player extends Orpheus
			constructor: ->
				@map @str 'name'
				@str 'color'
			
		player = Player.create()
		player name: 'rada', (err, player, new_player) ->
			expect(err).toBe null
			expect(new_player).toBe 'new user'
			
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
			player name: 'almog', (err, player, new_player) ->
				expect(new_player).toBeUndefined()
				
				player.set
					color: 'pink'
				.exec (err, res) ->
					expect(res[0]).toBe 0
					done()




