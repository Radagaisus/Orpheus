# Redis Commands
#-------------------------------------#
module.exports = 
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
		'zremreangebyrank',
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
	
	command_map:
		add:
			num: 'hincrby'
			str: 'hset' # we don't optimize with hmset
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