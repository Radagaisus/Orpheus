(function() {
  var Orpheus, OrpheusAPI, async, command_map, commands, hash_commands, inflector, key_commands, log, os, redis, shorthands, string_commands, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __slice = Array.prototype.slice;

  redis = require('redis');

  _ = require('underscore');

  async = require('async');

  os = require('os');

  inflector = require('./inflector');

  log = console.log;

  Orpheus = {};

  commands = {
    str: ['hdel', 'hexists', 'hget', 'hsetnx', 'hset'],
    num: ['hdel', 'hexists', 'hget', 'hsetnx', 'hset', 'hincrby', 'hincrbyfloat'],
    list: ['blpop', 'brpop', 'brpoplpush', 'lindex', 'linsert', 'llen', 'lpop', 'lpush', 'lpushx', 'lrange', 'lrem', 'lset', 'ltrim', 'rpop', 'rpoplpush', 'rpush', 'rpushx'],
    set: ['sadd', 'scard', 'sdiff', 'sdiffstore', 'sinter', 'sinterstore', 'sismember', 'smembers', 'smove', 'spop', 'srandmember', 'srem', 'sunion', 'sunionstore'],
    zset: ['zadd', 'zcard', 'zcount', 'zincrby', 'zinterstore', 'zrange', 'zrangebyscore', 'zrank', 'zrem', 'zremreangebyrank', 'zremrangebyscore', 'zrevrange', 'zrevrangebyscore', 'zrevrank', 'zscore', 'zunionstore']
  };

  shorthands = {
    str: 'h',
    num: 'h',
    list: 'l',
    set: 's',
    zset: 'z'
  };

  command_map = {
    add: {
      num: 'hincrby',
      str: 'hset',
      set: 'sadd',
      zset: 'zincrby',
      list: 'lpush'
    },
    set: {
      num: 'hset',
      str: 'hset',
      set: 'sadd',
      zset: 'zadd',
      list: 'lpush'
    },
    "delete": {
      num: 'hdel',
      str: 'hdel',
      set: 'del',
      zset: 'del',
      list: 'del'
    }
  };

  hash_commands = ['hdel', 'hexists', 'hget', 'hgetall', 'hincrby', 'hincrbyfloat', 'hkeys', 'hlen', 'hmget', 'hmset', 'hset', 'hsetnx', 'hvals'];

  string_commands = ["append", "decr", "decrby", "get", "getbit", "getrange", "getset", "incr", "incrby", "incrbyfloat", "mget", "mset", "msetnx", "psetex", "set", "setbit", "setex", "setnx", "setrange", "strlen"];

  key_commands = ['del', 'dump', 'exists', 'expire', 'expireat', 'keys', 'migrate', 'move', 'object', 'persist', 'pexpire', 'pexpireat', 'pttl', 'randomkey', 'rename', 'renamenx', 'restore', 'sort', 'ttl', 'type'];

  Orpheus = (function() {

    function Orpheus() {}

    Orpheus.config = {
      prefix: 'eury'
    };

    Orpheus.configure = function(o) {
      return this.config = _.extend(this.config, o);
    };

    Orpheus.schema = {};

    Orpheus.id_counter = 0;

    Orpheus.unique_id = function() {
      return this.id_counter++;
    };

    Orpheus.topics = {};

    Orpheus.trigger = function(topic, o) {
      var sub, subs, _i, _len, _results;
      subs = this.topics[topic];
      if (!subs) return;
      _results = [];
      for (_i = 0, _len = subs.length; _i < _len; _i++) {
        sub = subs[_i];
        _results.push(sub(o));
      }
      return _results;
    };

    Orpheus.on = function(topic, f) {
      var _base;
      (_base = this.topics)[topic] || (_base[topic] = []);
      return this.topics[topic].push(f);
    };

    Orpheus._errors = [];

    Orpheus.errors = {
      get: function() {
        return this._errors;
      },
      flush: function() {
        return this._errors = [];
      }
    };

    Orpheus.create = function() {
      var OrpheusModel, model, name, q, _base;
      OrpheusModel = (function(_super) {

        __extends(OrpheusModel, _super);

        function OrpheusModel(name, q) {
          var f, _fn, _i, _len, _ref,
            _this = this;
          this.name = name;
          this.q = q;
          this.id = __bind(this.id, this);
          this.model = {};
          this.rels = [];
          this.rels_qualifiers = [];
          this.validations = [];
          this.fields = ['str', 'num', 'map', 'list', 'set', 'zset', 'relation'];
          _ref = this.fields;
          _fn = function(f) {
            return _this[f] = function(field, options) {
              if (options == null) options = {};
              this.model[field] = {
                type: f,
                options: options
              };
              return field;
            };
          };
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            f = _ref[_i];
            _fn(f);
          }
          OrpheusModel.__super__.constructor.call(this);
          Orpheus.schema[this.name] = this.model;
        }

        OrpheusModel.prototype.has = function(rel) {
          var qualifier;
          this.rels.push(rel);
          qualifier = rel.substr(0, 2);
          this.rels_qualifiers.push(qualifier);
          return this[rel] = function(id) {
            this["" + qualifier + "_id"] = id;
            return this;
          };
        };

        OrpheusModel.prototype.validate = function(key, func) {
          var _base;
          (_base = this.validations)[key] || (_base[key] = []);
          return this.validations[key].push(func);
        };

        OrpheusModel.prototype.private = function(field) {
          return this.model[field].options.private = true;
        };

        OrpheusModel.prototype.id = function(id) {
          return new OrpheusAPI(id, this);
        };

        return OrpheusModel;

      })(this);
      name = this.toString().match(/function (.*)\(/)[1].toLowerCase();
      q = name.substr(0, 2);
      (_base = Orpheus.schema).models || (_base.models = {});
      Orpheus.schema.models[name] = this;
      model = new OrpheusModel(name, q);
      return model.id;
    };

    return Orpheus;

  })();

  OrpheusAPI = (function() {

    function OrpheusAPI(id, model) {
      var existing_id, f, key, prel, rel, value, _fn, _fn2, _fn3, _fn4, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref, _ref2, _ref3, _ref4, _ref5,
        _this = this;
      this.model = model;
      _.extend(this, this.model);
      this._commands = [];
      existing_id = id;
      this.id = id || this.generate_id();
      this.redis = Orpheus.config.client;
      this.prefix = Orpheus.config.prefix;
      this.pname = inflector.pluralize(this.name);
      this.validation_errors = [];
      _ref = this.rels;
      _fn = function(rel, prel) {
        return _this[prel].get = function(arr, fn) {
          var results;
          if (!arr.length) return fn(null, []);
          results = [];
          return async.until(function() {
            return results.length === arr.length;
          }, function(c) {
            model = Orpheus.schema.models[rel].create();
            model(arr[results.length]).get(function(err, res) {
              if (err) {
                err.time = new Date();
                err.level = 'ERROR';
                err.type = 'Redis';
                err.msg = 'Failed retrieving related models';
                this._errors.push(err);
                Orpheus.trigger('error', err);
              } else {
                results.push(res);
              }
              return c(err);
            });
            return model[results.length];
          }, function(err) {
            return fn(err, results);
          });
        };
      };
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        rel = _ref[_i];
        prel = inflector.pluralize(rel);
        this[prel] = {};
        _ref2 = commands.set;
        _fn2 = function(prel, f) {
          return _this[prel][f] = function() {
            var args, fn, _k;
            args = 2 <= arguments.length ? __slice.call(arguments, 0, _k = arguments.length - 1) : (_k = 0, []), fn = arguments[_k++];
            return _this.redis[f](["" + _this.prefix + ":" + _this.q + ":" + _this.id + ":" + prel].concat(args), fn);
          };
        };
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          f = _ref2[_j];
          _fn2(prel, f);
        }
        _fn(rel, prel);
      }
      _ref3 = this.model;
      for (key in _ref3) {
        value = _ref3[key];
        this[key] = {};
        _ref4 = commands[value.type];
        _fn3 = function(key, f) {
          _this[key][f] = function() {
            var args;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            _this._commands.push(_.flatten([f, _this.get_key(key), args]));
            return _this;
          };
          if (f[0] !== shorthands[value.type]) return;
          return _this[key][f.slice(1)] = function() {
            var args;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            _this._commands.push(_.flatten([f, _this.get_key(key), args]));
            return _this;
          };
        };
        for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
          f = _ref4[_k];
          _fn3(key, f);
        }
      }
      this.operations = ['add', 'set', 'del'];
      _ref5 = this.operations;
      _fn4 = function(f) {
        return _this[f] = function(o) {
          var command, k, msg, type, v, valid, _len5, _m, _ref6;
          for (k in o) {
            v = o[k];
            if (this.validations[k]) {
              _ref6 = this.validations[k];
              for (_m = 0, _len5 = _ref6.length; _m < _len5; _m++) {
                valid = _ref6[_m];
                msg = valid(v);
                if (msg !== true) {
                  msg = new Error(msg.message);
                  msg.type = 'validation';
                  this.validation_errors.push(msg);
                }
              }
            }
            if (!this.validation_errors.length) {
              type = this.model[k].type;
              command = command_map[f][type];
              this[k][command](v);
            }
          }
          return this;
        };
      };
      for (_l = 0, _len4 = _ref5.length; _l < _len4; _l++) {
        f = _ref5[_l];
        _fn4(f);
      }
    }

    OrpheusAPI.prototype.generate_id = function() {
      var counter, host, pid, s, time, _i, _len, _ref;
      time = "" + (new Date().getTime());
      pid = process.pid;
      host = 0;
      _ref = os.hostname();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        host += s.charCodeAt(0);
      }
      counter = Orpheus.unique_id();
      return "" + host + pid + time + counter;
    };

    OrpheusAPI.prototype.get_key = function(key) {
      var k, rel, type, _i, _len, _ref;
      k = "" + this.prefix + ":" + this.q + ":" + this.id;
      _ref = this.rels_qualifiers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        rel = _ref[_i];
        if (this[rel + "_id"]) k += (":" + rel + ":") + this[rel + "_id"];
      }
      if (!key) return k;
      type = this.model[key].type;
      if (key && this.model[key].options.key) key = this.model[key].options.key();
      if (type === 'str' || type === 'num') {
        return [k, key];
      } else {
        return ["" + k + ":" + key];
      }
    };

    OrpheusAPI.prototype.get = function(fn) {
      return this.getall(fn, true);
    };

    OrpheusAPI.prototype["delete"] = function(fn) {
      var hdel_flag, key, type, value, _ref,
        _this = this;
      hdel_flag = false;
      _ref = this.model;
      for (key in _ref) {
        value = _ref[key];
        type = value.type;
        if (type === 'str' || type === 'num') {
          if (!hdel_flag) {
            hdel_flag = true;
            this._commands.push(['del', this.get_key()]);
          }
        } else {
          this._commands.push(['del', this.get_key(key)]);
        }
      }
      return this.redis.multi(this._commands).exec(function(err, res) {
        return fn(err, res, _this.id);
      });
    };

    OrpheusAPI.prototype.getall = function(fn, private) {
      var hash_parts_are_private, hgetall_flag, hmget, key, not_private, schema, type, value, _ref,
        _this = this;
      if (private == null) private = false;
      not_private = function() {
        return !private || private && value.options.private !== true;
      };
      schema = [];
      hgetall_flag = false;
      hash_parts_are_private = false;
      hmget = [];
      _ref = this.model;
      for (key in _ref) {
        value = _ref[key];
        type = value.type;
        switch (type) {
          case 'str':
          case 'num':
            hgetall_flag = true;
            if (not_private()) {
              hmget.push(key);
            } else {
              hash_parts_are_private = true;
            }
            break;
          case 'list':
            if (not_private()) {
              this._commands.push(['lrange', this.get_key(key), 0, -1]);
              schema.push(key);
            }
            break;
          case 'set':
            if (not_private()) {
              this._commands.push(['smembers', this.get_key(key)]);
              schema.push(key);
            }
            break;
          case 'zset':
            if (not_private()) {
              this._commands.push(['zrange', this.get_key(key), 0, -1, 'withscores']);
              schema.push(key);
            }
        }
      }
      if (hash_parts_are_private) {
        if (hmget.length) {
          this._commands.push(['hmget', this.get_key()].concat(hmget));
          schema.push(hmget);
        }
      } else if (hgetall_flag) {
        this._commands.push(['hgetall', this.get_key()]);
        schema.push('hash');
      }
      return this.redis.multi(this._commands).exec(function(err, res) {
        var i, j, o, prop, result, _len, _len2;
        result = false;
        if (err) {
          err.time = new Date();
          err.level = 'ERROR';
          err.type = 'Redis';
          err.msg = 'Failed getting model';
          _this._errors.push(err);
          Orpheus.trigger('error', err);
        } else {
          result = {};
          for (i = 0, _len = schema.length; i < _len; i++) {
            o = schema[i];
            if (o === 'hash') {
              _.extend(result, res[i]);
            } else if (_.isArray(o)) {
              for (j = 0, _len2 = o.length; j < _len2; j++) {
                prop = o[j];
                result[prop] = res[i][j];
              }
            } else {
              result[o] = res[i];
            }
          }
          result.id = _this.id;
        }
        return fn(err, result);
      });
    };

    OrpheusAPI.prototype.exec = function(fn) {
      var _this = this;
      if (this.validation_errors.length) {
        return fn(this.validation_errors, false, this.id);
      }
      return this.redis.multi(this._commands).exec(function(err, res) {
        if (err) {
          err.time = new Date();
          err.level = 'ERROR';
          err.type = 'Redis';
          err.msg = 'Failed Multi Execution';
          _this._errors.push(err);
          Orpheus.trigger('error', err);
        }
        return fn(err, res, _this.id);
      });
    };

    return OrpheusAPI;

  })();

  module.exports = Orpheus;

}).call(this);
