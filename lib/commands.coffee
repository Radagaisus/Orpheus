# Redis Commands
# ------------------------------------------------------------------------------------
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
		'zcard',
		'zcount',
		'zlexcount',
		'zrange',
		'zrangebylex',
		'zrevrangebylex',
		'zrangebyscore',
		'zrank',
		'zrevrange',
		'zrevrangebyscore',
		'zrevrank',
		'zscore',
		# Hash, String, Number
		'hget',
		'hgetall',
		'hmget',
		'hstrlen'
	]
	
	str: [
		'hdel',
		'hexists',
		'hget',
		'hset',
		'hsetnx',
		'hstrlen'
	]
	
	num: [
		'hdel',
		'hexists',
		'hget',
		'hincrby',
		'hincrbyfloat',
		'hset',
		'hsetnx',
		'hstrlen'
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
		'sunionstore',
		'sscan'
	]
	
	zset: [
		'zadd',
		'zcard',
		'zcount',
		'zincrby',
		'zinterstore',
		'zlexcount',
		'zrange',
		'zrangebylex',
		'zrevrangebylex',
		'zrangebyscore',
		'zrank',
		'zrem',
		'zremrangebylex',
		'zremrangebyrank',
		'zremrangebyscore',
		'zrevrange',
		'zrevrangebyscore',
		'zrevrank',
		'zscore',
		'zunionstore',
		'zscan'
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

	# Operations that can be called on zset, set, hash and list attributes
	keys: [
		'del'
		'dump'
		'exists'
		'expire'
		'expireat'
		'persist'
		'pexpire'
		'pexpireat'
		'pttl'
		'restore'
		'sort'
		'ttl'
		'type'
		'scan'
	]
	
	shorthands:
		str: 'h'
		num: 'h'
		list: 'l'
		set: 's'
		zset: 'z'
		hash: 'h'
	
	# This maps commands for the `add()`, `set()` and `delete()` functions. Adding in a set
	# results in `sadd`, deleting a number is `hdel`, etc.
	command_map:
		add:
			num: 'hincrby'
			str: 'hset'      # We don't 'optimize' with hmset
			set: 'sadd'
			zset: 'zincrby'
			list: 'lpush'
		
		set:
			num: 'hset'
			str: 'hset'
			set: 'sadd'
			zset: 'zadd'
			list: 'lpush'

