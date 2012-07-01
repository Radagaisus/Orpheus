Orpheus = require '../index'
redis = require 'redis'
metrics = require 'metrics'
async = require 'async'

client = redis.createClient()
log = console.log
PREFIX = 'orpheus:benchmark'
Orpheus.configure
	client: client
	prefix: PREFIX

rand_str = (len = 20) ->
	("abcdefghijklmnopqrstwxyz"[Math.floor(Math.random() * 24)] for i in [1..len]).join('')

rand_num = (min = 0, max = 10000) ->
	min + Math.floor(Math.random() * max)

class Player extends Orpheus
	constructor: ->
		@str 'small'
		@str 'long'
		@num 'points'
player = Player.create()
REQUESTS = 20000

log "  Orpheus Benchmark"
log "------------------------"

test = (desc, fn) ->
	return (callback) ->
		i = 0
		time = new Date().getTime()
		async.whilst ->
				i < REQUESTS
			, (cb) ->
				i++
				fn cb
			, (err) ->
				log "#{desc} | #{REQUESTS} requests | #{new Date().getTime() - time}ms"
				callback err

timer = new Date().getTime()
async.series [
			test "String | new id | small", (cb) -> player().small.set(rand_str(5)).exec(cb)
		,
			test "String | new id | long", (cb) -> player().long.set(rand_str(500)).exec(cb)
		,
			test "Number | new id | points", (cb) -> player().points.set(rand_num(50000, 1000000)).exec(cb)
	], (err) ->
		if err
			log "error."
		log "Test Time: #{new Date().getTime() - timer}ms"
		log "flushing benchmark keys..."
		
		client.keys "#{PREFIX}*", (err, keys) ->
			if err
				log "problem flushing benchmark keys"
				process.exit 1
			
			async.forEach keys, (i, cb) ->
						client.del i, cb
				, (err, res) ->
					if err
						log "problem cleaning test db"
						process.exit 1
					else
						log "done."
						process.exit()
