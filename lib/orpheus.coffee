# Orpheus - a small DSL for redis
#-------------------------------------#

_ = require 'underscore'           # flatten, extend, isString
async = require 'async'            # until
os = require 'os'                  # id generation
inflector = require './inflector'  # pluralize
commands = require './commands'    # redis commands
command_map = commands.command_map
validation_map = commands.validations
validations = require './validations'
log = console.log

# Orpheus
#-------------------------------------#
class Orpheus
	@version = "0.1.8"
	
	# Configuration
	@config:
		prefix: 'orpheus' # redis prefix, orpheus:obj:id:prop
		# client -       the redis client we should use
	
	@configure: (o) ->
		@config = _.extend @config, o
	
	# easy reference to all models
	@schema = {}
	
	# UniqueID counters
	@id_counter: 0
	@unique_id: -> @id_counter++
	
	# Mini pub/sub for errors
	@topics = {}
	
	@trigger = (topic, o) ->
		subs = @topics[topic]
		return unless subs
		(sub o for sub in subs)
	
	@on = (topic, f) ->
		@topics[topic] ||= []
		@topics[topic].push f
	
	# Orpheus model extends the model
	# - we can automagically detect
	#   the model name and qualifier.
	# - you don't need to call super()
	@create: ->
		
		class OrpheusModel extends @
			
			constructor: (@name, @q) ->
				@redis = Orpheus.config.client
				@prefix = Orpheus.config.prefix
				@pname = inflector.pluralize @name
				@model = {}
				@rels = []
				@rels_qualifiers = []
				@validations = []
				
				@fields = [
					'str'  # @str 'name'
					'num'  # @num 'points'
					'list' # @list 'activities'
					'set'  # @set  'uniques'
					'zset' # @zset 'ranking'
					'hash' # @hash 'progress'
				]
				
				# Create a simple schema for all fields
				for f in @fields
					do (f) =>
						@[f] = (field, options = {}) ->
							throw new Error("Field name already taken") if @model[field]
							
							@model[field] =
								type: f
								options: options
							
							return field
				
				# Create the model
				super()
			
			# Add mapping
			map: (field) ->
				throw new Error("Map only works on strings") if @model[field].type isnt 'str'
				@model[field].options.map = true
			
			# Add relations
			has: (rel) ->
				@rels.push rel
				qualifier = rel.substr(0,2)
				@rels_qualifiers.push qualifier
				
				# create a relation function,
				# e.g. user(12).book(15)
				@[rel] = (id) ->
					@["#{qualifier}_id"] = id
					return @
			
			# Add a validation function to a field
			# Example:
			# @validate 'name', (name) ->
			#   if name is 'jay' then true else 'invalid!'
			validate: (key, o) ->
				@validations[key] ||= []
				
				if _.isFunction o
					@validations[key].push o
				else
					# Custom validations: numericality, exclusion, inclusion
					# format, etc. Validations are functions that recieve the
					# field and return either true or a string as a message
					if o.numericality
						for k,v of o.numericality
							do (k,v) =>
								@validations[key].push (field) ->
									unless validations.num[k].fn(field, v)
										return validations.num[k].msg(field, v)
									return true
					if o.exclusion
						@validations[key].push (field) ->
							if field in o.exclusion
								return "#{field} is reserved."
							return true
					
					if o.inclusion
						@validations[key].push (field) ->
							if field in o.inclusion
								return true
							return "#{field} is not included in the list."
					
					if o.format
						@validations[key].push (field) ->
							log o.format, field, o.format.test(field)
							if o.format.test(field)
								return true
							return "#{field} is invalid."
			
			# Mark field as private
			private: (field) ->
				@model[field].options.private = true
			
			# return OrpheusAPI if we have the id, or it's
			# a new id. otherwise, hget the id and then call
			# orpheus api.
			id: (id, fn) =>
				if not id or _.isString(id) or _.isNumber(id)
					if fn
						new_model = new OrpheusAPI(id, this)
						fn null, new_model, new_model.id, false
					else
						new OrpheusAPI(id, this)
				else
					for k,v of id
						pk = inflector.pluralize k
						@redis.hget "#{@prefix}:#{@pname}:map:#{pk}", v, (err, model_id) =>
							return fn err, false if err
							if model_id
								# existing
								new_model = new OrpheusAPI(model_id, this)
								fn null, new_model, model_id, false
							else
								# new
								model = new OrpheusAPI(null, this)
								model._add_map pk, v
								fn null, model, model.id, true
					
		
		# Converts class Player to 'player'
		name = @toString().match(/function (.*)\(/)[1].toLowerCase()
		
		# Qualifier
		q = name.substr(0,2)
		
		# Add to Schema
		Orpheus.schema[name] = @
		
		model = new OrpheusModel(name, q)
		return model.id


# Orpheus API
#-------------------------------------#
class OrpheusAPI
	constructor: (id, @model) ->
		
		_.extend @, @model
		
		# Redis multi commands
		@_commands = []
		
		@validation_errors = new OrpheusValidationErrors
		
		# new or existing id
		@id = id or @_generate_id()
		
		# Create functions for working with the relation set
		# e.g. user(15).books.sadd('dune') will map to sadd
		# orpheus:us:15:books dune.
		for rel in @rels
			prel = inflector.pluralize rel
			@[prel] = {}
			for f in commands.set
				do (prel, f) =>
					@[prel][f] = (args..., fn) =>
						@redis[f](["#{@prefix}:#{@q}:#{@id}:#{prel}"].concat(args), fn)
					
					# shorthand, use add instead of sadd
					@[prel][f[1..]] = @[prel][f]
			
			
			# user(10).books.get ['dune', 'valis']
			# Extract related models information,
			# one by one, based on an array of ids
			do (rel, prel) =>
				@[prel].get = (arr = [], fn) =>
					return fn null, [] unless arr.length
					results = []
					
					async.until ->
							results.length is arr.length
							
						, (c) ->
							# create the relation model
							model = Orpheus.schema[rel].create()
							
							# and get its information based on the arr id
							model(arr[results.length]).get (err, res) ->
								unless err
									results.push res
								c err
						, (err) ->
							fn err, results
				
				
				# user(10).books.each
				# Run in parallel using async
				@[prel].map = (arr = [], iter, done) =>
					i = 0
					async.map arr, (item, cb) ->
							iter item, cb, i++
						, done
				
				# Add all async functions.
				for k,v of async when not k in ['map', 'noConflict']
					@[prel][k] = v
		
		
		# Add all redis commands relevant to the field and its type
		# Example: model('id').ranking.zadd (zrank, zscore...)
		for key, value of @model
			@[key] = {}
			
			for f in commands[value.type]
				type = value.type
				do (key, f, type) =>
					@[key][f] = (args...) =>
						
						# Type Conversions
						if validation_map[f]
							if type is 'str'
								if typeof args[0] isnt 'string'
									if typeof args[0] is 'number'
										args[0] = args[0].toString()
									else
										@validation_errors.add key,
											msg: "Could not convert #{args[0]} to string"
											command: f
											args: args
											value: args[0]
							
							if type is 'num'
								if typeof args[0] isnt 'number'
									args[0] = Number args[0]
								if not isFinite(args[0]) or isNaN(args[0])
									@validation_errors.add key,
										msg: "Malformed number"
										command: f
										args: args
										value: args[0]
						
						# Add multi command
						@_commands.push _.flatten [f, @_get_key(key), args]
						
						# Run validation, if needed
						validation = validation_map[f]
						if validation and @validations[key]
							
							if type is 'str' or type is 'num'
								# Regular validations
								for v in @validations[key]
									result = v args...
									
									unless result is true
										@validation_errors.add key,
											msg: result
											command: f
											args: args
											value: args[0]
								
								# no need to check the extra commands
								return @ unless @validation_errors.valid()
						
						# Extra commands: mapping
						@_extra_commands(key, f, args) if @model[key].options.map
						
						return @
					
					# Shorthand form, incrby instead of zincrby and hincrby is also acceptable
					# str: h, num: h, list: l, set: s, zset: z
					@[key][f[1..]] = @[key][f] if f[0] is commands.shorthands[value.type]
		
		
		# create the add, set and del commands
		# based on the commands map they call
		# the respective command for the key,
		# value they recieve.
		@operations = ['add', 'set', 'del']
		for f in @operations
			do (f) =>
				@[f] = (o) ->
					for k, v of o
						# Add the Command. Note we won't actually
						# execute any of this commands if the
						# validation has failed.
						type = @model[k].type
						command = command_map[f][type]
						@[k][command](v) # e.g. @name.hset 'abe'
					
					return this
	
	
	# Generate a unique ID for model, similiar to MongoDB
	# http://www.mongodb.org/display/DOCS/Object+IDs
	_generate_id: ->
		time = "#{new Date().getTime()}" # we convert to a str to
		                                 # avoid 4.3e+79 as id
		pid = process.pid
		host = 0; (host += s.charCodeAt(0) for s in os.hostname())
		counter = Orpheus.unique_id()
		
		"#{host}#{pid}#{time}#{counter}"
	
	
	_get_key: (key) ->
		# Default: orpheus:pl:15
		k = "#{@prefix}:#{@q}:#{@id}"
		
		# Add qualifiers, if the relation was set.
		# e.g. orpheus:us:30:book:dune:page:13
		for rel in @rels_qualifiers when @[rel+"_id"]
			k += ":#{rel}:"+@[rel+"_id"]
		
		# delete and get just need the key for
		# del, hmget and hgetall
		return k unless key
		
		type = @model[key].type
		
		# generate a new key name, if it has a
		# dynamic key function.
		if key and @model[key].options.key
			key = @model[key].options.key()
		
		if type is 'str' or type is 'num'
			# orpheus:us:15:name somename
			return [k, key]
		else
			# orpheus:us:15:somelist
			return "#{k}:#{key}"
	
	_add_map: (field, key) ->
		@_commands.push ['hset', "#{@prefix}:#{@pname}:map:#{field}", key, @id]
	
	_extra_commands: (key, command, args) ->
		# Map stuff, e.g.
		# orpheus:users:map:fb_ids
		if @model[key].options.map and command is 'hset'
			pkey = inflector.pluralize key
			@_add_map pkey, args[0]
	
	# deletes the model.
	delete: (fn) ->
		# flush commands and validations
		@_commands = [] 
		@validation_errors.empty()
		
		hdel_flag = false # no need to delete a hash twice
		for key, value of @model
			type = value.type
			if type is 'str' or type is 'num'
				unless hdel_flag
					hdel_flag = true
					@_commands.push ['del', @_get_key()]
			else
				@_commands.push ['del', @_get_key(key)]
		
		@exec fn
	
	# get public information only
	get: (fn) ->
		@getall fn, true
	
	# get ALL the model information.
	getall: (fn, get_private = false) ->
		# Helper for determining if a value is private or not
		not_private = -> not get_private or get_private and value.options.private isnt true
		
		schema = [] # we use the schema to convert the response
		            # to the appropriate value
		
		# It's ugly and nasty, but sometimes we want hmget
		# and sometimes we want hgetall
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
						@_commands.push ['lrange', @_get_key(key), 0, -1]
						
				when 'set'
					if not_private()
						@_commands.push ['smembers', @_get_key(key)]
						
				when 'zset'
					if not_private()
						@_commands.push ['zrange', @_get_key(key), 0, -1, 'withscores']
						
				when 'hash'
					if not_private()
						@_commands.push ['hgetall', @_get_key(key)]
			
			schema.push key unless type is 'str' or type is 'num'
		
		if hash_parts_are_private
			if hmget.length
				@_commands.push ['hmget', @_get_key()].concat(hmget)
				schema.push hmget
		else if hgetall_flag
			@_commands.push ['hgetall', @_get_key()]
			schema.push 'hash'
		
		@exec (err, res, id) =>
			result = false
			unless err
				# convert the response type, based on the schmea
				result = {}
				for o,i in schema
					if o is 'hash'
						_.extend result, res[i]
					else if Array.isArray o
						for prop, j in o
							result[prop] = res[i][j]
					else
						result[o] = res[i]
				
				result.id = @id
			
			fn err, result, @id
	
	err: (fn) ->
		@error_func = fn
		return @
	
	# execute the multi commands
	exec: (fn) ->
		unless @validation_errors.valid()
			if @error_func
				return @error_func @validation_errors, @id
			else
				return fn @validation_errors, false, @id
		
		@redis
			.multi(@_commands)
			.exec (err, res) =>
				
				if @error_func
					if err
						err.time = new Date()
						err.level = 'ERROR'
						err.type = 'redis'
						err.msg = 'Failed Multi Execution'
						@_errors.push err
						Orpheus.trigger 'error', err
						
						@error_func err
					else
						fn res, @id
				else
					fn err, res, @id

# Orpheus Validation errors
#-------------------------------------#
class OrpheusValidationErrors
	
	constructor: ->
		@type = 'validation'
		@errors = {}
	
	valid: ->
		_.isEmpty @errors
	
	invalid: ->
		!@valid()
	
	add: (field, error) ->
		# Add date, useful for logging
		error.date = new Date().getTime()
		
		@errors[field] || = []
		@errors[field].push error
	
	empty: ->
		@errors = {}
	
	toResponse: ->
		# 400 is Bad Request
		# See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.1
		obj = {status: 400, errors: {}}
		
		# Add the validation error messages
		for k,v of @errors
			obj.errors[k] = (m.msg for m in v)
		obj

module.exports = Orpheus