// Generated by CoffeeScript 1.4.0
(function() {
  var EventEmitter, Orpheus, OrpheusAPI, OrpheusValidationErrors, async, command_map, commands, getters, inflector, log, os, validation_map, validations, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __slice = [].slice;

  _ = require('underscore');

  async = require('async');

  os = require('os');

  EventEmitter = require('events').EventEmitter;

  inflector = require('./inflector');

  commands = require('./commands');

  validations = require('./validations');

  command_map = commands.command_map;

  validation_map = commands.validations;

  getters = commands.getters;

  log = console.log;

  Orpheus = (function(_super) {

    __extends(Orpheus, _super);

    function Orpheus() {
      return Orpheus.__super__.constructor.apply(this, arguments);
    }

    Orpheus.version = "0.2.2";

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

    Orpheus.create = function() {
      var OrpheusModel, model, name, q;
      OrpheusModel = (function(_super1) {

        __extends(OrpheusModel, _super1);

        function OrpheusModel(name, q) {
          var f, _i, _len, _ref;
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
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            f = _ref[_i];
            this.create_field(f);
          }
          OrpheusModel.__super__.constructor.call(this);
        }

        OrpheusModel.prototype.create_field = function(f) {
          return this[f] = function(field, options) {
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
          this[rel] = function(id) {
            this["" + qualifier + "_id"] = this["" + rel + "_id"] = id;
            return this;
          };
          return this['un' + rel] = function() {
            return this["" + qualifier + "_id"] = this["" + rel + "_id"] = null;
          };
        };

        OrpheusModel.prototype.validate = function(key, o) {
          var k, tokenizer, v, _base, _fn, _ref, _ref1, _results,
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
              this.validations[key].push(function(field) {
                if (__indexOf.call(o.exclusion, field) >= 0) {
                  if (o.message) {
                    return o.message(field);
                  } else {
                    return "" + field + " is reserved.";
                  }
                }
                return true;
              });
            }
            if (o.inclusion) {
              this.validations[key].push(function(field) {
                if (__indexOf.call(o.inclusion, field) >= 0) {
                  return true;
                }
                if (o.message) {
                  return o.message(field);
                } else {
                  return "" + field + " is not included in the list.";
                }
              });
            }
            if (o.format) {
              this.validations[key].push(function(field) {
                if (o.format.test(field)) {
                  return true;
                }
                if (o.message) {
                  return o.message(field);
                } else {
                  return "" + field + " is invalid.";
                }
              });
            }
            if (o.size) {
              tokenizer = o.size.tokenizer || function(field) {
                return field.length;
              };
              _ref1 = o.size;
              _results = [];
              for (k in _ref1) {
                v = _ref1[k];
                _results.push((function(k, v) {
                  if (k === 'tokenizer') {
                    return;
                  }
                  return _this.validations[key].push(function(field) {
                    var len;
                    len = tokenizer(field);
                    if (!validations.size[k].fn(len, v)) {
                      return validations.size[k].msg(field, len, v);
                    }
                    return true;
                  });
                })(k, v));
              }
              return _results;
            }
          }
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

  })(EventEmitter);

  OrpheusAPI = (function() {

    function OrpheusAPI(id, model) {
      var f, key, prel, rel, value, _fn, _fn1, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3, _ref4,
        _this = this;
      this.model = model;
      this._create_getter_object = __bind(this._create_getter_object, this);

      _.extend(this, this.model);
      this._commands = [];
      this.validation_errors = new OrpheusValidationErrors;
      this._res_schema = [];
      this.id = id || this._generate_id();
      this.only = this.when = function(fn) {
        fn.bind(_this)();
        return _this;
      };
      _ref = this.rels;
      _fn = function(rel, prel) {
        var k, v, _ref1, _results;
        _this[prel].map = function(arr, iter, done) {
          var i;
          if (arr == null) {
            arr = [];
          }
          i = 0;
          return async.map(arr, function(item, cb) {
            return iter(item, cb, i++);
          }, done);
        };
        _results = [];
        for (k in async) {
          v = async[k];
          if ((_ref1 = !k) === 'map' || _ref1 === 'noConflict') {
            _results.push(_this[prel][k] = v);
          }
        }
        return _results;
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
            _this.redis[f](["" + _this.prefix + ":" + _this.q + ":" + _this.id + ":" + prel].concat(args), fn);
            return _this;
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
        for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
          f = _ref3[_k];
          this._create_command(key, value, f);
        }
      }
      this.operations = ['add', 'set', 'del'];
      _ref4 = this.operations;
      for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
        f = _ref4[_l];
        this._add_op(f);
      }
    }

    OrpheusAPI.prototype._create_command = function(key, value, f) {
      var type,
        _this = this;
      type = value.type;
      this[key][f] = function() {
        var args, dynamic_key_args, result, v, _i, _len, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        if (_.isObject(args[args.length - 1]) && args[args.length - 1].key) {
          dynamic_key_args = args.pop().key;
        }
        if (validation_map[f]) {
          if (type === 'str') {
            if (typeof args[0] !== 'string') {
              if (typeof args[0] === 'number') {
                args[0] = args[0].toString();
              } else {
                _this.validation_errors.add(key, {
                  msg: "Could not convert " + args[0] + " to string",
                  command: f,
                  args: args,
                  value: args[0]
                });
                return;
              }
            }
          }
          if (type === 'num') {
            if (typeof args[0] !== 'number') {
              args[0] = Number(args[0]);
            }
            if (!isFinite(args[0]) || isNaN(args[0])) {
              _this.validation_errors.add(key, {
                msg: "Malformed number",
                command: f,
                args: args,
                value: args[0]
              });
              return;
            }
          }
        }
        _this._commands.push(_.flatten([f, _this._get_key(key, dynamic_key_args), args]));
        if (__indexOf.call(getters, f) >= 0) {
          _this._res_schema.push({
            type: type,
            name: key,
            with_scores: type === 'zset' && __indexOf.call(args, 'withscores') >= 0
          });
        }
        if (validation_map[f] && _this.validations[key]) {
          if (type === 'str' || type === 'num') {
            _ref = _this.validations[key];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              v = _ref[_i];
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
        return this[key][f.slice(1)] = this[key][f];
      }
    };

    OrpheusAPI.prototype._add_op = function(f) {
      return this[f] = function(o) {
        var command, k, type, v;
        for (k in o) {
          v = o[k];
          if (typeof this.model[k] === 'undefined') {
            throw new Error("Orpheus :: No Such Model Attribute: " + k);
          }
          type = this.model[k].type;
          command = command_map[f][type];
          this[k][command](v);
        }
        return this;
      };
    };

    OrpheusAPI.prototype._generate_id = function() {
      var counter, host, pid, random, s, time, _i, _len, _ref;
      this._new_id = true;
      time = "" + (new Date().getTime());
      pid = process.pid;
      host = 0;
      _ref = os.hostname();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        host += s.charCodeAt(0);
      }
      counter = Orpheus.unique_id();
      random = Math.round(Math.random() * 1000);
      return "" + host + pid + time + counter + random;
    };

    OrpheusAPI.prototype._get_key = function(key, dynamic_key_args) {
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
        key = this.model[key].options.key.apply(this, dynamic_key_args);
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

    OrpheusAPI.prototype.flush = function() {
      this._commands = [];
      this.validation_errors.empty();
      return this._res_schema = [];
    };

    OrpheusAPI.prototype["delete"] = function(fn) {
      var hdel_flag, key, type, value, _ref;
      this.flush();
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
      var key, type, value, _ref;
      _ref = this.model;
      for (key in _ref) {
        value = _ref[key];
        type = value.type;
        switch (type) {
          case 'str':
          case 'num':
            this[key].get();
            break;
          case 'list':
            this[key].range(0, -1);
            break;
          case 'set':
            this[key].members();
            break;
          case 'zset':
            this[key].range(0, -1, 'withscores');
            break;
          case 'hash':
            this[key].hgetall();
        }
      }
      return this.exec(fn);
    };

    OrpheusAPI.prototype._create_getter_object = function(res) {
      var field, i, index, member, new_res, s, temp_res, zset, _i, _j, _len, _len1, _ref, _ref1, _step;
      new_res = {};
      temp_res = {};
      _ref = this._res_schema;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        s = _ref[i];
        if (s.type === 'num') {
          res[i] = Number(res[i]);
        } else if (s.type === 'zset' && s.with_scores) {
          zset = {};
          _ref1 = res[i];
          for (index = _j = 0, _len1 = _ref1.length, _step = 2; _j < _len1; index = _j += _step) {
            member = _ref1[index];
            zset[member] = Number(res[i][index + 1]);
          }
          res[i] = zset;
        }
        if (new_res[s.name] != null) {
          if (temp_res[s.name] != null) {
            temp_res[s.name].push(res[i]);
          } else {
            temp_res[s.name] = [new_res[s.name], res[i]];
          }
          new_res[s.name] = temp_res[s.name];
        } else {
          new_res[s.name] = res[i];
        }
        field = new_res[s.name];
        if (_.isNull(field) || _.isUndefined(field) || (_.isObject(field) && _.isEmpty(field))) {
          if (_.isUndefined(this.model[s.name].options["default"])) {
            delete new_res[s.name];
          } else {
            new_res[s.name] = this.model[s.name].options["default"];
          }
        }
      }
      return new_res;
    };

    OrpheusAPI.prototype.err = function(fn) {
      this.error_func = fn || function() {};
      return this;
    };

    OrpheusAPI.prototype.exec = function(fn) {
      var _this = this;
      fn || (fn = function() {});
      if (!this.validation_errors.valid()) {
        if (this.error_func) {
          return this.error_func(this.validation_errors, this.id);
        } else {
          return fn(this.validation_errors, null, this.id);
        }
      }
      return this.redis.multi(this._commands).exec(function(err, res) {
        if (_this._res_schema.length && !err) {
          if (_this._res_schema.length === _this._commands.length) {
            res = _this._create_getter_object(res);
          }
        }
        if (_this.error_func) {
          if (err) {
            err.time = new Date();
            err.level = 'ERROR';
            err.type = 'redis';
            err.msg = 'Failed Multi Execution';
            _this._errors.push(err);
            Orpheus.emit('error', err);
            return _this.error_func(err);
          } else {
            if (_this._new_id) {
              return fn(res, _this.id);
            } else {
              return fn(res);
            }
          }
        } else {
          if (_this._new_id) {
            return fn(err, res, _this.id);
          } else {
            return fn(err, res);
          }
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
