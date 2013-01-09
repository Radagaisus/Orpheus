# Redis Commands
#-------------------------------------#
module.exports = 
	validations:
		# String
		hsetnx:       true
		hset:         true
		
		# Number
		hincrby:      true
		hincrbyfloat: true
		
		# List
		lpush:        true # several values, 1
		lpushx:       true
		rpush:        true # several values, 1
		rpushx:       true
		
		# Set
		sadd:         true # several values, 1
		
		# Zset
		zadd:         true # several values, reverted, 2
		zincrby:      true # reverted
		
		# Hash
		hmset:        true # several values, 2
		
		# Validations does not support:
		# - zinterstore
		# - zunionstore
		# - sunionstore
		# - smove
		# - sinterstore
		# - sdiffstore
		# - lset
		# - linsert
		# - brpoplpush and friends
	
	getters: [

		# List
		'lrange',
		'llen',
		
		# Set
		'smembers',
		'scard',
		
		# Zset
		'zrange',
		'zrangebyscore',
		'zrevrange',
		'zrevrangebyscore',
		'zscore',
		'zrank',
		'zrevrank',
		'zcount',
		'zcard',
		
		# Hash, String, Number
		'hget',
		'hgetall',
		'hmget'
	]
	
	str: [
		'hdel',
		'hexists',
		'hget',
		'hsetnx',
		'hset'
	]
	
	num: [
		'hdel',
		'hexists',
		'hget',
		'hsetnx',
		'hset',
		'hincrby',
		'hincrbyfloat'
	]
	
	list: [
		'blpop',
		'brpop',
		'brpoplpush',
		'lindex',
		'linsert',
		'llen',
		'lpop',
		'lpush',
		'lpushx',
		'lrange',
		'lrem',
		'lset',
		'ltrim',
		'rpop',
		'rpoplpush',
		'rpush',
		'rpushx'
	]
	
	set: [
		'sadd',
		'scard',
		'sdiff',
		'sdiffstore',
		'sinter',
		'sinterstore',
		'sismember',
		'smembers',
		'smove',
		'spop',
		'srandmember',
		'srem',
		'sunion',
		'sunionstore'
	]
	
	zset: [
		'zadd',
		'zcard',
		'zcount',
		'zincrby',
		'zinterstore',
		'zrange',
		'zrangebyscore',
		'zrank',
		'zrem',
		'zremrangebyrank',
		'zremrangebyscore',
		'zrevrange',
		'zrevrangebyscore',
		'zrevrank',
		'zscore',
		'zunionstore'
	]
	
	hash: [
		'hdel',
		'hexists',
		'hget',
		'hgetall',
		'hincrby',
		'hincrbyfloat',
		'hkeys',
		'hlen',
		'hmget',
		'hmset',
		'hset',
		'hsetnx',
		'hvals'
	]
	
	shorthands:
		str: 'h'
		num: 'h'
		list: 'l'
		set: 's'
		zset: 'z'
		hash: 'h'
	
	# This maps commands for the add(),
	# set() and delete() functions.
	# Adding in a set results in sadd,
	# deleting a num is hdel, etc.
	command_map:
		add:
			num: 'hincrby'
			str: 'hset'      # we don't 'optimize' with hmset
			set: 'sadd'
			zset: 'zincrby'
			list: 'lpush'
		
		set:
			num: 'hset'
			str: 'hset'
			set: 'sadd'
			zset: 'zadd'
			list: 'lpush'
		
		delete:
			num: 'hdel'
			str: 'hdel'
			set: 'del'
			zset: 'del'
			list: 'del'