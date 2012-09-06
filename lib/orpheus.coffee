# Orpheus - a small DSL for redis
#-------------------------------------#

_            = require 'underscore'           
async        = require 'async'            
os           = require 'os'                    # ID Generation
EventEmitter = require('events').EventEmitter

inflector    = require './inflector'   # Inflection
commands     = require './commands'    # redis commands
validations  = require './validations' # Validations

command_map    = commands.command_map
validation_map = commands.validations
getters        = commands.getters

log = console.log

# Orpheus
#-------------------------------------#
class Orpheus extends EventEmitter
	@version = "0.1.9"
	
	# Configuration
	@config:
		prefix: 'orpheus' # redis prefix, orpheus:obj:id:prop
		# client -        # redis client
	
	@configure: (o) ->
		@config = _.extend @config, o
	
	# easy reference to all models
	@schema = {}
	
	# UniqueID counters
	@id_counter: 0
	@unique_id: -> @id_counter++
	
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
				@create_field f for f in @fields
				
				# Create the model
				super()
			
			create_field: (f) ->
				@[f] = (field, options = {}) ->
					throw new Error("Field name already taken") if @model[field]
					
					@model[field] =
						type: f
						options: options
					
					return field

			# Add mapping
			map: (field) ->
				if @model[field].type isnt 'str'
					throw new Error("Map only works on strings")
				@model[field].options.map = true
			
			# Add relations
			has: (rel) ->
				@rels.push rel
				qualifier = rel.substr(0,2)
				@rels_qualifiers.push qualifier
				
				# create a relation function,
				# e.g. user(12).book(15)
				@[rel] = (id) ->
					@["#{qualifier}_id"] = @["#{rel}_id"]= id
					return @

				@['un'+rel] = ->
					@["#{qualifier}_id"] = @["#{rel}_id"] = null
			
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
								if o.message
									return o.message field
								else
									return "#{field} is reserved."
							return true
					
					if o.inclusion
						@validations[key].push (field) ->
							if field in o.inclusion
								return true
							if o.message
								return o.message field
							else
								return "#{field} is not included in the list."
					
					if o.format
						@validations[key].push (field) ->
							if o.format.test(field)
								return true
							if o.message
								return o.message field
							else
								return "#{field} is invalid."
					
					if o.size
							tokenizer = o.size.tokenizer or (field) -> field.length
							for k,v of o.size
								do (k,v) =>
									return if k is 'tokenizer'
									@validations[key].push (field) ->
										len = tokenizer field
										unless validations.size[k].fn(len, v)
											return validations.size[k].msg(field, len, v)
										return true


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
		
		# Used when retrieving information from redis
		# This schema tells us how to convert the reponse
		@_res_schema = []
		
		# New or existing id
		@id = id or @_generate_id()
		
		# If and Unless are used to discard changes
		# unless certain conditions are met
		@only = @when = (fn) =>
			fn.bind(this)()
			return this
		
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
						return this
					
					# shorthand, use add instead of sadd
					@[prel][f[1..]] = @[prel][f]
			
			
			# Async functions for handling relations
			do (rel, prel) =>
				
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
				@_create_command key, value, f
		
		
		# Create the Add, Set and Del commands
		@operations = ['add', 'set', 'del']
		for f in @operations
			@_add_op f
	

	_create_command: (key, value, f) ->
		type = value.type

		@[key][f] = (args...) =>
			
			# Type Conversion
			# ------------------------
			# Convert types for all the commands
			# in the validation map.
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
							return
				
				if type is 'num'
					if typeof args[0] isnt 'number'
						args[0] = Number args[0]
					if not isFinite(args[0]) or isNaN(args[0])
						@validation_errors.add key,
							msg: "Malformed number"
							command: f
							args: args
							value: args[0]
						return
			
			# Add multi command
			@_commands.push _.flatten [f, @_get_key(key), args]
			
			# Response Schema
			# --------------------
			# If the command is a get command
			if f in getters
				@_res_schema.push
					position: @_commands.length - 1
					type: type
					name: key
					with_scores: type is 'zset' and 'withscores' in args
			
			# Run validation, if needed
			if validation_map[f] and @validations[key]
				
				if type in ['str', 'num']
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


	# Creates the Add, Set and Del commands,
	# based on the commands map.
	_add_op: (f) ->
		@[f] = (o) ->
			for k, v of o

				# Throw error on undefined attributes
				if typeof @model[k] is 'undefined'
					throw new Error "Orpheus :: No Such Model Attribute: #{k}"

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
		time = "#{new Date().getTime()}"
		pid = process.pid
		host = 0; (host += s.charCodeAt(0) for s in os.hostname())
		counter = Orpheus.unique_id()
		random = Math.round(Math.random() * 1000)
		"#{host}#{pid}#{time}#{counter}#{random}"
	
	
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
	
	# Extra commands
	_extra_commands: (key, command, args) ->
		# Map stuff, e.g.
		# orpheus:users:map:fb_ids
		if @model[key].options.map and command is 'hset'
			pkey = inflector.pluralize key
			@_add_map pkey, args[0]
	
	# Empties the object to be reused
	flush: ->
		@_commands = []
		@validation_errors.empty()
		@_res_schema = []
	
	# deletes the model.
	delete: (fn) ->
		# flush commands and validations
		@flush()
		
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
		for key, value of @model
			type = value.type
			switch type
				when 'str', 'num'
					@[key].get()
				when 'list'
					@[key].range 0, -1
				when 'set'
					@[key].members()
				when 'zset'
					@[key].range 0, -1, 'withscores'
				when 'hash'
					@[key].hgetall()
		
		@exec fn
	
	# Convert the results back from the multi
	# values we get from node redis. The response
	# schema, @_res_schema, is populated when we
	# add commands, and now, based on the types it
	# stored, we convert everything back to an object.
	_create_getter_object: (res) ->
		new_res = {}

		for s in @_res_schema
			# Convert numbers from their string representation
			if s.type is 'num'
				new_res[s.name] = Number res[s.position]

			# Convert zsets with scores to a key->value hash
			else if s.type is 'zset' and s.with_scores
				new_res[s.name] = {}

				for member,index in res[s.position] by 2
					new_res[s.name][member] = Number res[s.position][index+1]

			# Add everything else as attributes
			else
				new_res[s.name] = res[s.position]
			
			# Remove Empty values: null, undefined and []
			if not new_res[s.name] or (_.isEmpty(new_res[s.name]) and _.isObject(new_res[s.name]))
				delete new_res[s.name]

		return new_res

	# 
	err: (fn) ->
		@error_func = fn || -> # noop
		return @
	
	# execute the multi commands
	exec: (fn) ->
		fn ||= -> # noop
		
		unless @validation_errors.valid()
			if @error_func
				return @error_func @validation_errors, @id
			else
				return fn @validation_errors, false, @id
		
		@redis
			.multi(@_commands)
			.exec (err, res) =>
				
				# If the request was just for getting information,
				# convert the results back based on the response
				# scehma.
				if @_res_schema.length and not err
					if @_res_schema.length is @_commands.length
						res = @_create_getter_object res
				
				# Check whether we should call the error or function
				# or the execute function, and if we call the execute
				# function with which parameters.
				if @error_func
					if err
						err.time = new Date()
						err.level = 'ERROR'
						err.type = 'redis'
						err.msg = 'Failed Multi Execution'
						@_errors.push err
						Orpheus.emit 'error', err
						
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
		# 400 - Bad Request
		# See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.1
		obj = {status: 400, errors: {}}
		
		# Add the validation error messages
		for k,v of @errors
			obj.errors[k] = (m.msg for m in v)
		obj

# Export
module.exports = Orpheus