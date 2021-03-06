# Orpheus - a small DSL for Redis
# -------------------------------------------------------------------------------

_            = require 'underscore'           
async        = require 'async'        
os           = require 'os'
clone        = require 'clone'

# Require the inflector, that takes care of pluralizing model relationships
inflector    = require './inflector'

# Require the commands module. It contains a bunch of dictionaries that tell
# us how to handle different model field types, different Redis commands,
# their shorthands, and validations.
commands     = require './commands'
# Require the validations module, that contains a bunch of validation methods.
validations  = require './validations'

command_map    = commands.command_map
validation_map = commands.validations
getters        = commands.getters

# Orpheus
# ----------------------------------------------------------------------------
# 
class Orpheus
	@version = require('../package.json').version
	
	# Configuration
	@config:
		prefix: 'orpheus' # Redis prefix, `orpheus:obj:id:prop`
		# client -        # Redis client
	
	@configure: (o) ->
		@config = _.extend @config, o
	
	# Easy reference to all models
	@schema = {}
	
	# UniqueID counters
	@id_counter: 0
	@unique_id: -> @id_counter++


	# Connects lazy commands from several Orpheus models into one big MULTI
	# command. This is convenient, for example, for updating denormalized data
	# across several models.
	# 
	# Example usage:
	# 
	#   Orpheus.connect
	# 
	#     user:
	#       user('some-user')
	#       .points.set(200)
	#       .name.set('Snir')
	# 
	#     app:
	#       app('some-app')
	#       .points.set(1000)
	#       .name.set('Super App')
	# 
	#  , (err, res) ->
	#    # `res` is {user: [1,1], app: [1,1]}
	# 
	# 
	# @param models - {Object|Array} An object or an array of Orpheus models.
	# the keys in the object are the names we want to assign to the
	# response we return from Redis.
	# @param callback - {Function} a callback function, with the signature of
	# `(error, results)`. The results will be the parsed results from
	# Redis.
	# 
	@connect: (models, callback) ->
		# Holds a small schema, so we'll know how to return the results
		schema = {}
		# Holds all the multi commands we will issue
		multi_commands = []
		# Go over each modal and prepare a small schema
		for model_name, model of models
			# Get the model commands
			model_commands = model._commands
			# Note in the schema how many commands go per model
			schema[model_name] = model_commands.length
			# Add the model commands to the multi commands
			multi_commands = multi_commands.concat(model_commands)

		# Issue the request to Redis, and convert the schema in the callback
		Orpheus.config.client.multi(multi_commands).exec (err, results) ->
			# If there was an error, move on to the original callback
			if err then callback(err, results = [])
			else
				# The response
				response = {}
				# Go over the schema and convert it a a response object
				response[key] = results.splice(0, num) for key, num of schema
				# Call the callback, with the error and the parsed results
				callback(err, response)

	
	# Orpheus model extends the model
	# - we can automatically detect the model name and qualifier.
	# - you don't need to call super()
	@create: ->
		
		class OrpheusModel extends this
			
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
			
			
			# Creates a dynamic function that adds a field for
			# a specific type 'f'. For example, `create_field('str')`
			# will create the function `@str(field, options)` that
			# gets the field name and its options and pushes
			# them to the model schema.
			# 
			# @param f - {String} the field type, as string: 'str', 'num', etc
			# 
			create_field: (f) ->
				@[f] = (field, options = {}) ->
					throw new Error("Field name already taken") if @model[field]
					
					@model[field] =
						type   : f
						options: options
					
					return field

			# Add mapping
			map: (field) ->
				if @model[field].type isnt 'str'
					throw new Error("Map only works on strings")
				@model[field].options.map = true
			
			# Adds relations.
			# 
			# @param rel - {String} - the name of the relation
			# @param options - {Object} - options object:
			#   - namespace - if set, will use that namespace as
			#     the relation qualifier. By default we use the
			#     first two characters in the `rel` parameter.
			# 
			has: (rel, options = {}) ->
				# Get the relation qualifier, either the namespace
				# option or the first two characters in the `rel`.
				# used in the relation key. For example, the key
				# for a user in relation to a book will be:
				#   orpheus:us:{user_id}:bo:{book_id}
				qualifier = options.namespace || rel.substr(0,2)
				# Add the relation and the qualifier to our lists
				@rels.push(rel)
				@rels_qualifiers.push(qualifier)

				# e.g. `user(12).book(15)`
				@[rel] = (id) ->
					@["#{qualifier}_id"] = @["#{rel}_id"]= id
					return this

				@['un'+rel] = ->
					@["#{qualifier}_id"] = @["#{rel}_id"] = null
					return this
			

			# Adds a validation function to a field.
			# 
			# Example:
			# @validate 'name', (name) ->
			#   if name is 'jay' then true else 'invalid!'
			validate: (key, o) ->
				@validations[key] ||= []
				
				if _.isFunction o
					@validations[key].push o
				else

					# Custom validations: numericality, exclusion, inclusion
					# format, etc. Validations are functions that receive the
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


			
			# The `id` function is the main interface for querying Orpheus
			# models. After the model is created it can be "instantiated"
			# by calling this function. For example, after a User model
			# was created the `id` function will be available as
			# `orpheus.schema.user`.
			# 
			# The `id` function handles two cases: (1) where the model id
			# is known - we simply create a new OrpheusAPI instance and
			# return it; (2) when the model is being requested using a map:
			# when a model attribute is defined as `@map` we automatically
			# create a hash of `attribute_value -> model_id` under the key
			# `prefix:plural_model_name:map:plural_attribute_name`. For
			# example, if there's a map on the user name the key will look
			# as `orpheus:users:map:names`. When `id` is called using an
			# object of the form `{attribute_name: attribute_value}` we
			# first search the map hash for the model id. If we find it,
			# we return that model id. Otherwise, we create a new model.
			# 
			# When using the mapped version of the function, a callback
			# function must be passed as a second parameter. The callback
			# receives 3 parameters: `error` if there was an error, `id`
			# is the model id and `is_new` is a boolean indicating whether
			# this is a new model and a map was not found.
			# 
			# Usage:
			#   Orpheus.schema.user(req.user.id)
			#     name.set('colombus').exec()
			# 
			#   Orpheus.scehma.user()
			#     .name.set('whatever').exec()  
			# 
			#   Orpheus.schema.user name: 'colombus', (err, id, is_new) ->
			#     req.session.user.id = id
			# 
			# @param id - {Mixed} optional. either the model is as a number or a
			# string, or an object map to use to look up the model id, in the form
			# of `{attribute_name: attribute_value`}. If the id parameter is not
			# provided a new model id will be generated.
			# @param fn - {Function} optional. A callback function, used when
			# calling `id` with a map object.
			# @return an OrpheusAPI instance ready for querying the model.
			# 
			id: (id, fn) =>
				# If there is no ID or there is a regular string/number id
				if not id or _.isString(id) or _.isNumber(id)
					# If there's a callback function provided
					if fn
						# Create a new OrpheusAPI instance
						new_model = new OrpheusAPI(id, this)
						# Call the callback function
						fn(null, new_model, new_model.id, false)
					else
						# Simply create a new OrpheusAPI instance and return it
						new OrpheusAPI(id, this)
				# If the `id` parameter is a map object
				else if _.isObject(id) and fn
					# Break the map into an attribute name and value
					for name, value of id
						# Pluralize the attribute name
						plural_name = inflector.pluralize(name)
						# Create the Redis map key
						key = "#{@prefix}:#{@pname}:map:#{plural_name}"
						# Try to see if there's a hash record for the model
						# id using the map object value
						@redis.hget key, value, (err, model_id) =>
							return fn(err) if err
							# If there is an existing model record in the map
							if model_id
								# Create a new OrpheusAPI instance with the id
								new_model = new OrpheusAPI(model_id, this)
								# Call the callback function
								fn(null, new_model, model_id, false)
							# The model record was not found, we'll create a new one
							else
								# Create a new OrpheusAPI instance with no id
								new_model = new OrpheusAPI(null, this)
								# Add a map for the new model with the specified value
								new_model._add_map(plural_name, value)
								# Call the callback function
								fn(null, new_model, new_model.id, true)
				else
					# Throw an error, the `id` parameter was not passed correctly
					message = "Orpheus Model must be instantiated with a proper id"
					throw new Error(message)
					
		
		# Converts class Player to 'player'
		name = @toString().match(/function (.*)\(/)[1].toLowerCase()
		
		# Qualifier
		q = name.substr(0,2)
		
		model = new OrpheusModel(name, q)

		# Add to Schema
		Orpheus.schema[name] = model.id

		return model.id


# Orpheus API
# ------------------------------------------------------------------------------------
class OrpheusAPI
	constructor: (id, @model) ->
		
		_.extend @, @model
		
		# Redis multi commands
		@_commands = []

		# Initialize the query flags
		@flags = {}
		
		@validation_errors = new OrpheusValidationErrors
		
		# The response schema is used to figure out how
		# to convert the multi command array response to
		# a model object.
		# 
		# We populate the schema when the commands are
		# issued.
		# 
		# @_res_schema.push
		#   type: type         # The field type: 'num'
		#   name: key          # The field name: 'points'
		#   with_scores: false # used on zset commands with
		#                      # scores, as they are converted
		#                      # to either objects or arrays
		@_res_schema = []
		
		# New or existing id
		@id = id or @_generate_id()
		
		
		# Runs the given `function` inside the model context. Optionally, if `only`
		# or `when` receive the `condition` parameter it will only run the function
		# conditionally.
		# 
		# Example usage:
		#   
		#   User('john')
		#   .when ->
		#     if the_sky_is_blue then @name.set('happy john')
		#   .exec()
		# 
		#   User('john')
		#   .when the_sky_is_blue, ->
		#     @name.set('happy john')
		#   .exec()
		# 
		# @param condition - {Mixed} if just one argument is passed, `condition` is
		# assumed to be the function to run in the context of the model. If two arguments
		# are passed, `condition` will be used to evaluate whether to run the function or
		# not.
		# @param fn - {Function} the function to run in the context of the model
		# @return {this} for chaining
		# 
		@only = @when = (condition, fn = condition) =>
			# Apply the function in the current context if the condition is truthy
			fn.bind(this)() if condition
			# Return `this` for chaining
			return this
		
		
		# Create functions for working with the relation set
		# e.g. user(15).books.sadd('dune') will map to `sadd`
		# orpheus:us:15:books dune.
		for rel in @rels
			prel = inflector.pluralize(rel)
			@model[prel] = {type: 'set', options: {}}
			@[prel] = {}
		
		
		# Add all Redis commands relevant to the field and its type
		# Example: model('id').ranking.zadd (zrank, zscore...)
		for key, value of @model
			@[key] = {}
			# Add all the type commands
			for f in commands[value.type]
				@_create_command key, value, f
			# Add key commands (del, expire, etc)
			if value.type in ['set', 'zset', 'hash', 'list']
				for f in commands.keys
					@_create_command key, value, f
			
			do (key) =>
				# Add a `key` function, that supplies dynamic key arguments for keys
				@[key].key = (args...) =>
					@[key]._key_arguments = args
					return @[key]

				# Add a dynamic `.as` function for each key. When doing retrieval operations
				# `.as` can be called to note how we want the key name to be returned. `.as`
				# takes a single parameter, `key_name`, that declares the key name we want
				# to see the retrieved value placed at. `key_name` can be nested. For example,
				# you can use 'first.name' to create a nested object `{first: {name: value}}`.
				# 
				# Example Usage:
				#   user('1').name.as('first_name').get().exec (err, res) ->
				#     expect(res.first_name).toEqual 'the user name'
				# 
				#   user('1').name.as('name.first').get().exec (err, res) ->
				#     expect(res.name.first).toEqual 'the user name'
				# 
				# @param key_name - The key name we want to use for the retrieved value
				# @return {Object} the key object, for chaining of other commands
				# 
				@[key].as = (key_name) =>
					# Mark the key name we want to use as a flag to be used later
					@[key]._key_name = key_name
					# Return the key object for chaining
					return @[key]


		for rel in @rels
			prel = inflector.pluralize(rel)
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
		
		# Create the Add, Set and Del commands
		for f in ['add', 'set']
			@_add_op f


	_create_command: (key, value, f) ->
		type = value.type

		@[key][f] = (args...) =>
			
			# Pop out dynamic key arguments, if any
			if _.isObject(args[args.length-1]) and args[args.length-1].key
				dynamic_key_args = args.pop().key

			
			field = args[0]
			# Convert types for all the commands
			# in the validation map.
			if validation_map[f]
				# If the field should be a string field
				if type is 'str'
					# If it's not a string
					if not _.isString(field)
						# If it's a number
						if _.isNumber(field)
							# Convert to a string
							field = field.toString()
						# Otherwise, file a validation error
						else
							@validation_errors.add key,
								msg: "Could not convert #{key} to string"
								command: f
								args: args
								value: field
							return this
				
				if type is 'num'
					if not _.isNumber(field)
						field = Number(field)
					if not isFinite(field) or isNaN(field)
						@validation_errors.add key,
							msg: "Malformed number"
							command: f
							args: args
							value: field
						return this
			
			# Add multi command
			@_commands.push _.flatten [f, @_get_key(key, dynamic_key_args), args]
			
			# Response Schema
			# --------------------------------------

			# Extract the `_key_name` flag, so we can use it in the response schema.
			key_name = @[key]._key_name
			# And then delete it so it won't stay for future operations on the key.
			delete @[key]._key_name

			# If the command is a get command
			if f in getters
				@_res_schema.push
					type: type
					name: key
					key_name: key_name
					dynamic_key_args: dynamic_key_args
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
					return this unless @validation_errors.valid()
			
			# Extra commands: mapping
			@_extra_commands(key, f, args) if @model[key].options.map
			
			return this
		
		# Shorthand form, `incrby` instead of `zincrby` and `hincrby `is also acceptable
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

	# Generate a unique ID for model, similar to MongoDB
	# http://www.mongodb.org/display/DOCS/Object+IDs
	_generate_id: ->
		@_new_id = true
		time = "#{new Date().getTime()}"
		pid = process.pid
		host = 0; (host += s.charCodeAt(0) for s in os.hostname())
		counter = Orpheus.unique_id()
		random = Math.round(Math.random() * 1000)
		"#{host}#{pid}#{time}#{counter}#{random}"
	
	
	_get_key: (key, dynamic_key_args) ->
		# Default: orpheus:pl:15
		k = "#{@prefix}:#{@q}:#{@id}"
		
		# Add qualifiers, if the relation was set.
		# e.g. `orpheus:us:30:book:dune:page:13`
		for rel in @rels_qualifiers when @[rel+"_id"]
			k += ":#{rel}:"+@[rel+"_id"]
		
		# delete and get just need the key for
		# del, hmget and hgetall
		return k unless key
		
		type = @model[key].type
		
		# Generate a new key name, if it has a dynamic key function, and if it's not
		# just a request to get the regular model hash.
		if key and @model[key].options.key
			# If the dynamic key was supplied as a parameter, we use that. Otherwise,
			# we use the `@[key]._key_arguments` that was supplied using the `key`
			# function.
			if dynamic_key_args
				# Dynamic keys arguments can be passed in an array, or, if it's just one
				# key, as is.
				dynamic_key_args = [dynamic_key_args] unless _.isArray(dynamic_key_args)
			else
				dynamic_key_args = @[key]._key_arguments
			# Call the model key function with the dynamic key arguments to get the key
			key = @model[key].options.key.apply(this, dynamic_key_args)
		
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
	delete: ->
		hdel_flag = false # no need to delete a hash twice
		for key, value of @model
			type = value.type
			if type is 'str' or type is 'num'
				unless hdel_flag
					hdel_flag = true
					@_commands.push ['del', @_get_key()]
			else
				@_commands.push ['del', @_get_key(key)]
		return this
	
	# get public information only
	get: (fn) ->
		for key, value of @model
			type = value.type
			switch type
				when 'str', 'num' then @[key].get()
				when 'list'       then @[key].range 0, -1
				when 'set'        then @[key].members()
				when 'zset'       then @[key].range 0, -1, 'withscores'
				when 'hash'       then @[key].hgetall()
		
		@exec fn
	
	# Converts the results back from the multi
	# array values we get from node Redis. The response
	# schema, @_res_schema, is populated when we
	# add commands, and now, based on the types it
	# stored, we convert everything back to an object.
	_create_getter_object: (res) =>
		new_res  = {}
		temp_res = {}
		for s,i in @_res_schema

			# Convert fields that are set as Numbers in the schema to numbers
			# from the string representation we received from Redis.
			if s.type is 'num'
				res[i] = Number res[i]
			# If the field type is a zset, and the command requested the field
			# using `withscores`, convert the response to a `key -> value` hash
			# from the array of [key, val, ...] it was received in.
			else if s.type is 'zset' and s.with_scores
				# Initialize an empty object
				zset = {}
				# Go over each pair in the response for this command, and add them
				# to the `zset` object, after converting the value to a number.
				for member, index in res[i] by 2
					zset[member] = Number(res[i][index+1])
				# Add the converted `zset` to the response.
				res[i] = zset
			
			# If the `key_name` flag exists on the response schema, use it as the name
			# of the key for the retrieved value. See the `.as()` command definition for
			# more details on this.
			if s.key_name
				# Split the key for traversal based on dot syntax, e.g. 'first.name'
				traversal = s.key_name.split('.')
				# Go over each nesting
				for nesting, index in traversal
					# Use a temporary structure to help with recursion. Objects in JavaScript
					# are by-reference, so it's easy to do this in a loop.
					tmp = tmp || new_res
					# If we're at the last nesting level, add the retrieved value. Otherwise,
					# create an empty object, if it doesn't exist yet.
					if index + 1 is traversal.length
					then tmp[nesting] = res[i]
					else tmp[nesting] ||= {}
					# Update the temporary object to the next nesting level
					tmp = tmp[nesting]
			# Handle conversion of dynamic key responses. If the request only
			# issued one command for this dynamic key, add the response directly
			# under the key. If several commands were issued, add all the results
			# into an object with that dynamic key name. For example:
			# 
			#   User.book_author.get(key: ['1984']).exec()
			#   > {books: 'Orwell'}
			# 
			#   User
			#     .book_author.get(key: ['1984'])
			#     .book_author.get(key: ['asoiaf'])
			#   > {
			#       books: {
			#         '1984': 'Orwell',
			#         'asoiaf': 'GRRM'
			#       }
			#     }
			# 
			# Since we're going over the response items one by one, and don't want
			# to introduce another inner loop, the code below is a bit dirty. The
			# first time we receive a dynamic key we set it to `res[field_name`],
			# add add it's generated dynamic name to `res["#{field_name}_key"].
			# The next time, we check if this exist, and if so - convert into the
			# aforementioned object.
			# 
			else if @model[s.name].options.key
				# If this is the first command / response we parse for this field
				if not temp_res[s.name]?
					# Add it to the temporary response
					temp_res[s.name] = res[i]
					# And record the value of its dynamic key name
					temp_res["#{s.name}_key"] = @model[s.name]
						.options.key.apply(this, s.dynamic_key_args)
				# Otherwise, convert the previous (the first) command / response into
				# the object format, and add the new one there.
				else
					# Get the dynamic key name for the last key
					dynamic_key = temp_res["#{s.name}_key"]
					# If it exists, convert it to a new object
					if dynamic_key
						# Get its value into a temp variable
						tmp = temp_res[s.name]
						# Change it to an object
						temp_res[s.name] = {}
						# Set the field with its dynamic key to its value
						temp_res[s.name][dynamic_key] = tmp
						# And delete its dynamic key from the temp response
						delete temp_res["#{s.name}_key"]
					# Now add the current key into the new object that we created, first
					# by getting the name of its dynamic key
					dynamic_key = @model[s.name].options.key.apply(this, s.dynamic_key_args)
					temp_res[s.name][dynamic_key] = res[i]
				# Now add it to the `new_res` we return
				new_res[s.name] = temp_res[s.name]
			# Handle multiple commands and responses for the same field. If the
			# property already exists in the new response then we create an array
			# of results for this property. For example, issuing a `llen` and `lrange`
			# one of the other should return an array with their results, say:
			#   
			#   User.books.llen().books.lrange(0, -1).exec()
			#   > [3, [1, 2, 3]]
			# 
			else if new_res[s.name]?
				# We use temp_res as a temporary storage for the multiple results
				# array. If it's empty, we initialize it with the current response
				# and the last one found in `new_res[s.name]`. Otherwise, we just
				# push the new item to it.
				if temp_res[s.name]?
				then temp_res[s.name].push(res[i])
				else temp_res[s.name] = [new_res[s.name], res[i]]
				# Now assign it into the `new_res` that we return
				new_res[s.name] = temp_res[s.name]
			# Otherwise, just add the response to the `new_res` we return.
			else
				new_res[s.name] = res[i]
			
			# Get a quick reference to the current response field
			field = new_res[s.name]
			# If the field is `undefined`, `null`, or an empty object or array, then we
			# either use the field's default value or delete it from the response if
			# there's no default value.
			if _.isNull(field) or _.isUndefined(field) or (_.isObject(field) and _.isEmpty(field))
				# If no default value was set on the field, we delete it from the response.
				# Otherwise, we clone the default value and add it as the field in the response.
				if _.isUndefined @model[s.name].options.default
					# Delete the field from the response
					delete new_res[s.name]
				else
					# Clone the default value of the field, and add it to the response
					new_res[s.name] = clone(@model[s.name].options.default)

		# Return the new response
		return new_res

	# Marks the query to return raw response
	raw: ->
		@flags.raw_response = true
		# Return `this` for chaining
		return this

	# 
	err: (fn) ->
		@error_func = fn || -> # no-op
		return this
	
	# Executes all the commands in the current query
	# @param fn - {Function} callback function.
	exec: (fn) ->
		# Set the callback function to a no-op function by default
		fn ||= ->
		
		# If there were any validation errors we immediately call
		# the callback before issuing any commands to Redis. If
		# an error callback was supplied with `err` then we call
		# it with the validation errors and the model id. Otherwise
		# we call the `fn` callback with the errors, `null` as the
		# results and the model id.
		if @validation_errors.invalid()
			if @error_func
			then return @error_func(@validation_errors, @id)
			else return fn(@validation_errors, null, @id)

		@redis
			.multi(@_commands)
			.exec (err, res) =>
				
				# If the request was just for getting information,
				# convert the results back based on the response
				# schema.
				if @_res_schema.length and not err
					if @_res_schema.length is @_commands.length
						unless @flags.raw_response
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
						if @_new_id then fn res, @id
						else fn res
				else
					if @_new_id then fn err, res, @id
					else fn err, res


# Orpheus Validation errors
#---------------------------------------------------------------------
class OrpheusValidationErrors
	
	constructor: ->
		@type = 'validation'
		@errors = {}
	
	valid: ->
		_.isEmpty @errors
	
	invalid: ->
		not @valid()
	
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

# Export Orpheus
module.exports = Orpheus