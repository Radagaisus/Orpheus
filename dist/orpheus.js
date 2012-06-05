// Generated by CoffeeScript 1.3.3
(function() {
  var Orpheus, OrpheusAPI, OrpheusValidationErrors, async, command_map, commands, inflector, log, os, validation_map, validations, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __slice = [].slice;

  _ = require('underscore');

  async = require('async');

  os = require('os');

  inflector = require('./inflector');

  commands = require('./commands');

  command_map = commands.command_map;

  validation_map = commands.validations;

  validations = require('./validations');

  log = console.log;

  Orpheus = (function() {

    function Orpheus() {}

    Orpheus.config = {
      prefix: 'orpheus'
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
      if (!subs) {
        return;
      }
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

    Orpheus.create = function() {
      var OrpheusModel, model, name, q;
      OrpheusModel = (function(_super) {

        __extends(OrpheusModel, _super);

        function OrpheusModel(name, q) {
          var f, _fn, _i, _len, _ref,
            _this = this;
          this.name = name;
          this.q = q;
          this.id = __bind(this.id, this);

          this.redis = Orpheus.config.client;
          this.prefix = Orpheus.config.prefix;
          this.pname = inflector.pluralize(this.name);
          this.model = {};
          this.rels = [];
          this.rels_qualifiers = [];
          this.validations = [];
          this.fields = ['str', 'num', 'list', 'set', 'zset', 'hash'];
          _ref = this.fields;
          _fn = function(f) {
            return _this[f] = function(field, options) {
              if (options == null) {
                options = {};
              }
              if (this.model[field]) {
                throw new Error("Field name already taken");
              }
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
        }

        OrpheusModel.prototype.map = function(field) {
          if (this.model[field].type !== 'str') {
            throw new Error("Map only works on strings");
          }
          return this.model[field].options.map = true;
        };

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

        OrpheusModel.prototype.validate = function(key, o) {
          var k, v, _base, _fn, _ref,
            _this = this;
          (_base = this.validations)[key] || (_base[key] = []);
          if (_.isFunction(o)) {
            return this.validations[key].push(o);
          } else {
            if (o.numericality) {
              _ref = o.numericality;
              _fn = function(k, v) {
                return _this.validations[key].push(function(field) {
                  if (!validations.num[k].fn(field, v)) {
                    return validations.num[k].msg(field, v);
                  }
                  return true;
                });
              };
              for (k in _ref) {
                v = _ref[k];
                _fn(k, v);
              }
            }
            if (o.exclusion) {
              return this.validations[key].push(function(field) {
                if (__indexOf.call(o.exclusion, field) >= 0) {
                  return "" + field + " is reserved.";
                }
                return true;
              });
            }
          }
        };

        OrpheusModel.prototype["private"] = function(field) {
          return this.model[field].options["private"] = true;
        };

        OrpheusModel.prototype.id = function(id, fn) {
          var k, new_model, pk, v, _results,
            _this = this;
          if (!id || _.isString(id) || _.isNumber(id)) {
            if (fn) {
              new_model = new OrpheusAPI(id, this);
              return fn(null, new_model, new_model.id, false);
            } else {
              return new OrpheusAPI(id, this);
            }
          } else {
            _results = [];
            for (k in id) {
              v = id[k];
              pk = inflector.pluralize(k);
              _results.push(this.redis.hget("" + this.prefix + ":" + this.pname + ":map:" + pk, v, function(err, model_id) {
                var model;
                if (err) {
                  return fn(err, false);
                }
                if (model_id) {
                  new_model = new OrpheusAPI(model_id, _this);
                  return fn(null, new_model, model_id, false);
                } else {
                  model = new OrpheusAPI(null, _this);
                  model._add_map(pk, v);
                  return fn(null, model, model.id, true);
                }
              }));
            }
            return _results;
          }
        };

        return OrpheusModel;

      })(this);
      name = this.toString().match(/function (.*)\(/)[1].toLowerCase();
      q = name.substr(0, 2);
      Orpheus.schema[name] = this;
      model = new OrpheusModel(name, q);
      return model.id;
    };

    return Orpheus;

  })();

  OrpheusAPI = (function() {

    function OrpheusAPI(id, model) {
      var f, key, prel, rel, type, value, _fn, _fn1, _fn2, _fn3, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3, _ref4,
        _this = this;
      this.model = model;
      _.extend(this, this.model);
      this._commands = [];
      this.validation_errors = new OrpheusValidationErrors;
      this.id = id || this._generate_id();
      _ref = this.rels;
      _fn = function(rel, prel) {
        return _this[prel].get = function(arr, fn) {
          var results;
          if (arr == null) {
            arr = [];
          }
          if (!arr.length) {
            return fn(null, []);
          }
          results = [];
          return async.until(function() {
            return results.length === arr.length;
          }, function(c) {
            model = Orpheus.schema[rel].create();
            return model(arr[results.length]).get(function(err, res) {
              if (!err) {
                results.push(res);
              }
              return c(err);
            });
          }, function(err) {
            return fn(err, results);
          });
        };
      };
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        rel = _ref[_i];
        prel = inflector.pluralize(rel);
        this[prel] = {};
        _ref1 = commands.set;
        _fn1 = function(prel, f) {
          _this[prel][f] = function() {
            var args, fn, _k;
            args = 2 <= arguments.length ? __slice.call(arguments, 0, _k = arguments.length - 1) : (_k = 0, []), fn = arguments[_k++];
            return _this.redis[f](["" + _this.prefix + ":" + _this.q + ":" + _this.id + ":" + prel].concat(args), fn);
          };
          return _this[prel][f.slice(1)] = _this[prel][f];
        };
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          f = _ref1[_j];
          _fn1(prel, f);
        }
        _fn(rel, prel);
      }
      _ref2 = this.model;
      for (key in _ref2) {
        value = _ref2[key];
        this[key] = {};
        _ref3 = commands[value.type];
        _fn2 = function(key, f, type) {
          _this[key][f] = function() {
            var args, result, v, validation, _l, _len3, _ref4;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            _this._commands.push(_.flatten([f, _this._get_key(key), args]));
            validation = validation_map[f];
            if (validation && _this.validations[key]) {
              if (type === 'str' || type === 'num') {
                _ref4 = _this.validations[key];
                for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
                  v = _ref4[_l];
                  result = v.apply(null, args);
                  if (result !== true) {
                    _this.validation_errors.add(key, {
                      msg: result,
                      command: f,
                      args: args,
                      value: args[0]
                    });
                  }
                }
                if (!_this.validation_errors.valid()) {
                  return _this;
                }
              }
            }
            if (_this.model[key].options.map) {
              _this._extra_commands(key, f, args);
            }
            return _this;
          };
          if (f[0] === commands.shorthands[value.type]) {
            return _this[key][f.slice(1)] = _this[key][f];
          }
        };
        for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
          f = _ref3[_k];
          type = value.type;
          _fn2(key, f, type);
        }
      }
      this.operations = ['add', 'set', 'del'];
      _ref4 = this.operations;
      _fn3 = function(f) {
        return _this[f] = function(o) {
          var command, k, v;
          for (k in o) {
            v = o[k];
            type = this.model[k].type;
            command = command_map[f][type];
            this[k][command](v);
          }
          return this;
        };
      };
      for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
        f = _ref4[_l];
        _fn3(f);
      }
    }

    OrpheusAPI.prototype._generate_id = function() {
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

    OrpheusAPI.prototype._get_key = function(key) {
      var k, rel, type, _i, _len, _ref;
      k = "" + this.prefix + ":" + this.q + ":" + this.id;
      _ref = this.rels_qualifiers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        rel = _ref[_i];
        if (this[rel + "_id"]) {
          k += (":" + rel + ":") + this[rel + "_id"];
        }
      }
      if (!key) {
        return k;
      }
      type = this.model[key].type;
      if (key && this.model[key].options.key) {
        key = this.model[key].options.key();
      }
      if (type === 'str' || type === 'num') {
        return [k, key];
      } else {
        return "" + k + ":" + key;
      }
    };

    OrpheusAPI.prototype._add_map = function(field, key) {
      return this._commands.push(['hset', "" + this.prefix + ":" + this.pname + ":map:" + field, key, this.id]);
    };

    OrpheusAPI.prototype._extra_commands = function(key, command, args) {
      var pkey;
      if (this.model[key].options.map && command === 'hset') {
        pkey = inflector.pluralize(key);
        return this._add_map(pkey, args[0]);
      }
    };

    OrpheusAPI.prototype["delete"] = function(fn) {
      var hdel_flag, key, type, value, _ref;
      this._commands = [];
      this.validation_errors.empty();
      hdel_flag = false;
      _ref = this.model;
      for (key in _ref) {
        value = _ref[key];
        type = value.type;
        if (type === 'str' || type === 'num') {
          if (!hdel_flag) {
            hdel_flag = true;
            this._commands.push(['del', this._get_key()]);
          }
        } else {
          this._commands.push(['del', this._get_key(key)]);
        }
      }
      return this.exec(fn);
    };

    OrpheusAPI.prototype.get = function(fn) {
      return this.getall(fn, true);
    };

    OrpheusAPI.prototype.getall = function(fn, get_private) {
      var hash_parts_are_private, hgetall_flag, hmget, key, not_private, schema, type, value, _ref,
        _this = this;
      if (get_private == null) {
        get_private = false;
      }
      not_private = function() {
        return !get_private || get_private && value.options["private"] !== true;
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
              this._commands.push(['lrange', this._get_key(key), 0, -1]);
            }
            break;
          case 'set':
            if (not_private()) {
              this._commands.push(['smembers', this._get_key(key)]);
            }
            break;
          case 'zset':
            if (not_private()) {
              this._commands.push(['zrange', this._get_key(key), 0, -1, 'withscores']);
            }
            break;
          case 'hash':
            if (not_private()) {
              this._commands.push(['hgetall', this._get_key(key)]);
            }
        }
        if (!(type === 'str' || type === 'num')) {
          schema.push(key);
        }
      }
      if (hash_parts_are_private) {
        if (hmget.length) {
          this._commands.push(['hmget', this._get_key()].concat(hmget));
          schema.push(hmget);
        }
      } else if (hgetall_flag) {
        this._commands.push(['hgetall', this._get_key()]);
        schema.push('hash');
      }
      return this.exec(function(err, res, id) {
        var i, j, o, prop, result, _i, _j, _len, _len1;
        result = false;
        if (!err) {
          result = {};
          for (i = _i = 0, _len = schema.length; _i < _len; i = ++_i) {
            o = schema[i];
            if (o === 'hash') {
              _.extend(result, res[i]);
            } else if (Array.isArray(o)) {
              for (j = _j = 0, _len1 = o.length; _j < _len1; j = ++_j) {
                prop = o[j];
                result[prop] = res[i][j];
              }
            } else {
              result[o] = res[i];
            }
          }
          result.id = _this.id;
        }
        return fn(err, result, _this.id);
      });
    };

    OrpheusAPI.prototype.err = function(fn) {
      this.error_func = fn;
      return this;
    };

    OrpheusAPI.prototype.exec = function(fn) {
      var _this = this;
      if (!this.validation_errors.valid()) {
        if (this.error_func) {
          return this.error_func(this.validation_errors, this.id);
        } else {
          return fn(this.validation_errors, false, this.id);
        }
      }
      return this.redis.multi(this._commands).exec(function(err, res) {
        if (_this.error_func) {
          if (err) {
            err.time = new Date();
            err.level = 'ERROR';
            err.type = 'Redis';
            err.msg = 'Failed Multi Execution';
            _this._errors.push(err);
            Orpheus.trigger('error', err);
            return _this.error_func(err);
          } else {
            return fn(res, _this.id);
          }
        } else {
          return fn(err, res, _this.id);
        }
      });
    };

    return OrpheusAPI;

  })();

  OrpheusValidationErrors = (function() {

    function OrpheusValidationErrors() {
      this.type = 'validation';
      this.errors = {};
    }

    OrpheusValidationErrors.prototype.valid = function() {
      return _.isEmpty(this.errors);
    };

    OrpheusValidationErrors.prototype.invalid = function() {
      return !this.valid();
    };

    OrpheusValidationErrors.prototype.add = function(field, error) {
      var _base;
      error.date = new Date().getTime();
      (_base = this.errors)[field] || (_base[field] = []);
      return this.errors[field].push(error);
    };

    OrpheusValidationErrors.prototype.empty = function() {
      return this.errors = {};
    };

    OrpheusValidationErrors.prototype.toResponse = function() {
      var k, m, obj, v, _ref;
      obj = {
        status: 400,
        errors: {}
      };
      _ref = this.errors;
      for (k in _ref) {
        v = _ref[k];
        obj.errors[k] = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = v.length; _i < _len; _i++) {
            m = v[_i];
            _results.push(m.msg);
          }
          return _results;
        })();
      }
      return obj;
    };

    return OrpheusValidationErrors;

  })();

  module.exports = Orpheus;

}).call(this);
