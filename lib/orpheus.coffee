# Orpheus - a small DSL for redis
#-------------------------------------#

redis = require 'redis'
_ = require 'underscore'
async = require 'async'
os = require 'os'
inflector = require './inflector'
commands = require './commands'

command_map = commands.command_map

log = console.log

Orpheus = {}

# 
#-------------------------------------#
class Orpheus
	
	# Configuration
	@config:
		prefix: 'eury'
	
	@configure: (o) ->
		@config = _.extend @config, o
	
	@schema = {}
	
	# UniqueID counters
	@id_counter: 0
	@unique_id: -> @id_counter++
	
	# Mini pub/sub
	@topics = {}
	@trigger = (topic, o) ->
		subs = @topics[topic]
		return unless subs
		(sub o for sub in subs)
	@on = (topic, f) ->
		@topics[topic] ||= []
		@topics[topic].push f
	
	@_errors = []
	@errors:
		get: -> @_errors
		flush: -> @_errors = []
	
	# So you won't have to call super()
	# and we can figure out the class
	# name and the redis qualifier
	@create: ->
		class OrpheusModel extends @
			
			constructor: (@name, @q) ->
				
				# Create DSL functions
				@model = {}
				@rels = []
				@rels_qualifiers = []
				@validations = []
				
				@fields = ['str', 'num', 'map', 'list', 'set', 'zset', 'relation']
				for f in @fields
					do (f) =>
						@[f] = (field, options = {}) ->
							@model[field] =
								type: f
								options: options
							return field
				
				super()
				
				# Add to Orpheus Schema
				Orpheus.schema[@name] = @model
			
			# Create a relationship function
			has: (rel) ->
				@rels.push rel
				qualifier = rel.substr(0,2)
				@rels_qualifiers.push qualifier
				@[rel] = (id) ->
					@["#{qualifier}_id"] = id
					return @
			
			validate: (key, func) ->
				@validations[key] ||= []
				@validations[key].push func
			
			private: (field) ->
				@model[field].options.private = true
			
			id: (id) => return new OrpheusAPI(id, this)
		
		# Converts class Player to 'player'
		name = @toString().match(/function (.*)\(/)[1].toLowerCase()
		q = name.substr(0,2) # the qualifier we use
		
		Orpheus.schema.models ||= {}
		Orpheus.schema.models[name] = @
		
		model = new OrpheusModel(name, q)
		return model.id


# 
#-------------------------------------#
class OrpheusAPI
	constructor: (id, @model) ->
		_.extend @, @model
		@_commands = []
		existing_id = id
		@id = id or @generate_id()
		@redis = Orpheus.config.client
		@prefix = Orpheus.config.prefix
		@pname = inflector.pluralize @name
		@validation_errors = []
		
		# relations
		for rel in @rels
			prel = inflector.pluralize rel
			@[prel] = {}
			for f in commands.set
				do (prel, f) =>
					@[prel][f] = (args..., fn) =>
						@redis[f](["#{@prefix}:#{@q}:#{@id}:#{prel}"].concat(args), fn)
			
			# Helper get
			do (rel, prel) =>
				@[prel].get = (arr, fn) =>
					return fn null, [] unless arr.length
					results = []
					
					async.until ->
							results.length is arr.length
						, (c) ->
							model = Orpheus.schema.models[rel].create()
							model(arr[results.length]).get (err, res) ->
								if err
									err.time = new Date()
									err.level = 'ERROR'
									err.type = 'Redis'
									err.msg = 'Failed retrieving related models'
									@_errors.push err
									Orpheus.trigger 'error', err
								else
									results.push res
								c err
							
							model[results.length]
						, (err) ->
							fn err, results 
		
		# Redis Commands
		for key, value of @model
			@[key] = {}
			
			for f in commands[value.type]
				do (key, f) =>
					@[key][f] = (args...) =>
						@_commands.push _.flatten [f, @get_key(key), args]
						return @
					
					return if f[0] isnt commands.shorthands[value.type]
					@[key][f[1..]] = (args...) =>
						@_commands.push _.flatten [f, @get_key(key), args]
						return @
		
		# Add, Set, Delete commands
		@operations = ['add', 'set', 'del']
		for f in @operations
			do (f) =>
				@[f] = (o) ->
					for k, v of o
						# validation
						if @validations[k]
							for valid in @validations[k]
								msg = valid(v)
								unless msg is true
									msg = new Error(msg.message)
									msg.type = 'validation'
									@validation_errors.push msg 
						
						# command
						unless @validation_errors.length
							type = @model[k].type
							command = command_map[f][type]
							@[k][command](v)
					return this
	
	
	# Generate a unique ID for model, inspired by MongoDB
	# http://www.mongodb.org/display/DOCS/Object+IDs
	generate_id: ->
		time = "#{new Date().getTime()}"
		pid = process.pid
		host = 0; (host += s.charCodeAt(0) for s in os.hostname())
		counter = Orpheus.unique_id()
		"#{host}#{pid}#{time}#{counter}"
	
	get_key: (key) ->
		
		k = "#{@prefix}:#{@q}:#{@id}"
		for rel in @rels_qualifiers when @[rel+"_id"]
			k += ":#{rel}:"+@[rel+"_id"]
		
		return k unless key
		
		type = @model[key].type
		
		if key and @model[key].options.key
			key = @model[key].options.key()
		
		if type is 'str' or type is 'num'
			return [k, key]
		else
			return ["#{k}:#{key}"]
	
	get: (fn) ->
		@getall fn, true
	
	delete: (fn) ->
		hdel_flag = false
		for key, value of @model
			type = value.type
			if type is 'str' or type is 'num'
				unless hdel_flag
					hdel_flag = true
					@_commands.push ['del', @get_key()]
			else
				@_commands.push ['del', @get_key(key)]
		
		@redis
			.multi(@_commands)
			.exec (err, res) =>
				fn err, res, @id
	
	getall: (fn, private = false) ->
		not_private = -> not private or private and value.options.private isnt true
		
		schema = []
		
		hgetall_flag = false
		hash_parts_are_private = false
		hmget = []
		
		for key, value of @model
			type = value.type
			switch type
				when 'str', 'num'
					hgetall_flag = true
					if not_private()
						hmget.push key
					else
						hash_parts_are_private = true
				when 'list'
					if not_private()
						@_commands.push ['lrange', @get_key(key), 0, -1]
						schema.push key
				when 'set'
					if not_private()
						@_commands.push ['smembers', @get_key(key)]
						schema.push key
				when 'zset'
					if not_private()
						@_commands.push ['zrange', @get_key(key), 0, -1, 'withscores']
						schema.push key
		
		if hash_parts_are_private
			if hmget.length
				@_commands.push ['hmget', @get_key()].concat(hmget)
				schema.push hmget
		else if hgetall_flag
			@_commands.push ['hgetall', @get_key()]
			schema.push 'hash'
		
		@redis
			.multi(@_commands)
			.exec (err, res) =>
				result = false
				if err
					err.time = new Date()
					err.level = 'ERROR'
					err.type = 'Redis'
					err.msg = 'Failed getting model'
					@_errors.push err
					Orpheus.trigger 'error', err
				else
					result = {}
					for o,i in schema
						if o is 'hash'
							_.extend result, res[i]
						else if _.isArray o
							for prop, j in o
								result[prop] = res[i][j]
						else
							result[o] = res[i]
					
					result.id = @id
				
				fn err, result
	
	exec: (fn) ->
		if @validation_errors.length
			return fn @validation_errors, false, @id
		
		@redis
			.multi(@_commands)
			.exec (err, res) =>
				if err
					err.time = new Date()
					err.level = 'ERROR'
					err.type = 'Redis'
					err.msg = 'Failed Multi Execution'
					@_errors.push err
					Orpheus.trigger 'error', err
				fn err, res, @id

module.exports = Orpheus