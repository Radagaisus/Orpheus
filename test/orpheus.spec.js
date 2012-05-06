(function() {
  var Orpheus, PREFIX, clean_db, commands, getWeek, log, monitor, r, redis, util,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Orpheus = require('../lib/orpheus');

  redis = require('redis');

  util = require('util');

  r = redis.createClient();

  monitor = redis.createClient();

  commands = [];

  monitor.monitor();

  monitor.on('monitor', function(time, args) {
    commands || (commands = []);
    return commands.push("" + (util.inspect(args)));
  });

  log = console.log;

  PREFIX = "eury";

  clean_db = function(fn) {
    return r.keys("" + PREFIX + "*", function(err, keys) {
      var i, k, _len;
      if (err) {
        log("problem cleaning test db");
        process.exit;
      }
      for (i = 0, _len = keys.length; i < _len; i++) {
        k = keys[i];
        r.del(keys[i]);
      }
      if (fn) return fn();
    });
  };

  getWeek = function(date) {
    var d, daynum, m, offset, prev_offset, w, y;
    y = date.getFullYear();
    m = date.getMonth();
    d = date.getDate();
    offset = 8 - new Date(y, 0, 1).getDay();
    if (offset === 8) offset = 1;
    daynum = (Date.UTC(y, m, d, 0, 0, 0) - Date.UTC(y, 0, 1, 0, 0, 0)) / 86400000 + 1;
    w = Math.floor((daynum - offset + 7) / 7);
    if (w === 0) {
      y--;
      prev_offset = 7 + 1 - new Date(y, 0, 1).getDay();
      if (prev_offset === 2 || prev_offset === 8) {
        w = 53;
      } else {
        w = 52;
      }
    }
    return w;
  };

  clean_db();

  Orpheus.configure({
    client: redis.createClient(),
    prefix: 'eury'
  });

  afterEach(function(done) {
    return runs(function() {
      var command, _i, _len;
      log('');
      log('');
      log(" Test #" + (this.id + 1) + " Commands - " + this.description);
      log("------------------------");
      for (_i = 0, _len = commands.length; _i < _len; _i++) {
        command = commands[_i];
        log(command);
      }
      log("------------------------");
      commands = [];
      return clean_db(done);
    });
  });

  describe('Redis Commands', function() {
    it('Special Keys', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('name', {
            key: function() {
              return "oogabooga";
            }
          });
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('hola').name.set('almog').exec(function() {
        return r.hget("" + PREFIX + ":pl:hola", 'oogabooga', function(err, res) {
          expect(res).toBe('almog');
          return done();
        });
      });
    });
    it('Num and Str single commands', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('name');
          this.num('points');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('id').name.hset('almog').name.set('almog').points.incrby(5).points.incrby(10).exec(function(err, res) {
        expect(err).toBe(null);
        expect(res.length).toBe(4);
        expect(res[0]).toBe(1);
        expect(res[1]).toBe(0);
        expect(res[2]).toBe(5);
        expect(res[3]).toBe(15);
        return r.multi().hget("" + PREFIX + ":pl:id", 'name').hget("" + PREFIX + ":pl:id", 'points').exec(function(err, res) {
          expect(res[0]).toBe('almog');
          expect(res[1]).toBe('15');
          return done();
        });
      });
    });
    it('List commands', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.list('somelist');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('id').somelist.push(['almog', 'radagaisus', '13']).somelist.lrange(0, -1).exec(function(err, res) {
        expect(err).toBe(null);
        expect(res[0]).toBe(3);
        expect(res[1][0]).toBe('13');
        return done();
      });
    });
    it('Set commands', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.set('badges');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('id').badges.add(['lots', 'of', 'badges']).badges.card().exec(function(err, res) {
        expect(err).toBe(null);
        expect(res[0]).toBe(3);
        expect(res[0]).toBe(3);
        return done();
      });
    });
    return it('Zset commands', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.zset('badges');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('1234').badges.zadd(15, 'woot').badges.zincrby(3, 'woot').exec(function(err, res) {
        expect(err).toBe(null);
        expect(res[0]).toBe(1);
        expect(res[1]).toBe('18');
        return done();
      });
    });
  });

  describe('Get Stuff', function() {
    it('Get All', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.has('game');
          this.str('name');
          this.list('wins');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('someplayer').name.set('almog').wins.lpush(['a', 'b', 'c']).game('skyrim').name.set('mofasa').exec(function() {
        done();
        return player('someplayer').getall(function(err, res) {
          expect(res.name).toBe('almog');
          expect(res.wins[0]).toBe('c');
          return player('someplayer').game('skyrim').getall(function(err, res) {
            expect(res.name).toBe('mofasa');
            return done();
          });
        });
      });
    });
    return it('Get without private', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.has('game');
          this.private(this.str('name'));
          this.list('wins');
          this.str('hoho');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('someplayer').name.set('almog').wins.lpush(['a', 'b', 'c']).game('skyrim').name.set('mofasa').hoho.set('woo').exec(function() {
        return player('someplayer').get(function(err, res) {
          expect(res.name).toBeUndefined();
          expect(res.wins[0]).toBe('c');
          return player('someplayer').game('skyrim').get(function(err, res) {
            expect(res.name).toBeUndefined();
            expect(res.hoho).toBe('woo');
            return done();
          });
        });
      });
    });
  });

  describe('Relations', function() {
    it('One has', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.has('game');
          this.str('name');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('someplayer').name.set('almog').game('skyrim').name.set('mofasa').exec(function(err, res) {
        expect(err).toBe(null);
        expect(res[0]).toBe(1);
        expect(res[1]).toBe(1);
        return r.multi().hget("" + PREFIX + ":pl:someplayer", 'name').hget("" + PREFIX + ":pl:someplayer:ga:skyrim", 'name').exec(function(err, res) {
          expect(res[0]).toBe('almog');
          expect(res[1]).toBe('mofasa');
          return done();
        });
      });
    });
    return it('Should get relation information', function(done) {
      var Game, Player, game, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.has('game');
          this.str('name');
        }

        return Player;

      })(Orpheus);
      Game = (function(_super) {

        __extends(Game, _super);

        function Game() {
          this.has('player');
        }

        return Game;

      })(Orpheus);
      game = Game.create();
      player = Player.create();
      return game('diablo').players.sadd('15', '16', '17', function() {
        return player('15').name.set('almog').exec(function() {
          return player('16').name.set('almog').exec(function() {
            return player('17').name.set('almog').exec(function() {
              return game('diablo').players.smembers(function(err, players) {
                expect(err).toBe(null);
                return game('diablo').players.get(players, function(err, players) {
                  var p, _i, _len;
                  expect(err).toBeUndefined();
                  expect(players.length).toBe(3);
                  for (_i = 0, _len = players.length; _i < _len; _i++) {
                    p = players[_i];
                    expect(p.name).toBe('almog');
                  }
                  return done();
                });
              });
            });
          });
        });
      });
    });
  });

  describe('Setting Records', function() {
    it('Setting Strings', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('name');
          this.str('favourite_color');
          this.str('best_movie');
          this.str('wassum');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('15').set({
        name: 'benga',
        wassum: 'finger',
        best_movie: 5,
        favourite_color: 'stingy'
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
          expect(err).toBe(null);
          expect(res.name).toBe('benga');
          expect(res.wassum).toBe('finger');
          expect(res.best_movie).toBe('5');
          expect(res.favourite_color).toBe('stingy');
          return done();
        });
      });
    });
    it('Setting Numbers', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.num('bingo');
          this.num('mexico');
          this.num('points');
          this.num('nicaragua');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().set({
        bingo: 5,
        mexico: 7,
        points: 15,
        nicaragua: 234345
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
          expect(err).toBe(null);
          expect(res.bingo).toBe('5');
          expect(res.mexico).toBe('7');
          expect(res.points).toBe('15');
          expect(res.nicaragua).toBe('234345');
          return done();
        });
      });
    });
    it('Setting Lists with a string', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.list('activities', {
            type: 'str'
          });
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().set({
        activities: 'bingo'
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.lrange("" + PREFIX + ":pl:" + id + ":activities", 0, -1, function(err, res) {
          expect(err).toBe(null);
          expect(res.length).toBe(1);
          expect(res[0]).toBe('bingo');
          return done();
        });
      });
    });
    it('Setting Lists with Array', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.list('activities', {
            type: 'str'
          });
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().set({
        activities: ['bingo', 'mingo', 'lingo']
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.lrange("" + PREFIX + ":pl:" + id + ":activities", 0, -1, function(err, res) {
          expect(err).toBe(null);
          expect(res.length).toBe(3);
          expect(res[0]).toBe('lingo');
          expect(res[1]).toBe('mingo');
          expect(res[2]).toBe('bingo');
          return done();
        });
      });
    });
    it('Setting Sets with String', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.set('badges');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player(15).set({
        badges: 'badge'
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).toBe(15);
        return r.smembers("" + PREFIX + ":pl:15:badges", function(err, res) {
          expect(res[0]).toBe('badge');
          return done();
        });
      });
    });
    it('Setting Sets with Array', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.set('badges');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player(15).set({
        badges: ['badge1', 'badge2', 'badge3', 'badge3']
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).toBe(15);
        return r.smembers("" + PREFIX + ":pl:15:badges", function(err, res) {
          expect(res).not.toBe(null);
          expect(res.length).toBe(3);
          expect(res).toContain('badge1');
          expect(res).toContain('badge2');
          expect(res).toContain('badge3');
          return done();
        });
      });
    });
    return it('Setting Zsets', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.zset('badges');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player(2222).set({
        badges: [5, 'badge1']
      }).set({
        badges: [10, 'badge2']
      }).set({
        badges: [7, 'badge3']
      }).exec(function(err, id) {
        expect(err).toBe(null);
        return r.zrange("" + PREFIX + ":pl:2222:badges", 0, -1, 'withscores', function(err, res) {
          var i, r, success, _len;
          expect(err).toBe(null);
          success = ['badge1', '5', 'badge3', '7', 'badge2', '10'];
          for (i = 0, _len = res.length; i < _len; i++) {
            r = res[i];
            expect(r).toBe(success[i]);
          }
          return done();
        });
      });
    });
  });

  describe('Adding to Records', function() {
    it('Should add strings in a record', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('name');
          this.str('favourite_color');
          this.str('best_movie');
          this.str('wassum');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().add({
        name: 'benga',
        wassum: 'finger',
        best_movie: 5,
        favourite_color: 'stingy'
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
          expect(err).toBe(null);
          expect(res.name).toBe('benga');
          expect(res.wassum).toBe('finger');
          expect(res.best_movie).toBe('5');
          expect(res.favourite_color).toBe('stingy');
          return done();
        });
      });
    });
    it('Should add numbers in a record', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.num('bingo');
          this.num('mexico');
          this.num('points');
          this.num('nicaragua');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().add({
        bingo: 5,
        mexico: 7,
        points: 15,
        nicaragua: 234345
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
          expect(err).toBe(null);
          expect(res.bingo).toBe('5');
          expect(res.mexico).toBe('7');
          expect(res.points).toBe('15');
          expect(res.nicaragua).toBe('234345');
          player(id).add({
            bingo: 45,
            mexico: 63,
            points: 10,
            nicaragua: 1
          }).exec(function(err, res, id) {
            expect(err).toBe(null);
            expect(id).not.toBe(null);
            return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
              expect(err).toBe(null);
              expect(res.bingo).toBe('50');
              expect(res.mexico).toBe('70');
              expect(res.points).toBe('25');
              return expect(res.nicaragua).toBe('234346');
            });
          });
          return done();
        });
      });
    });
    return it('Should add lists in a record (with an array)', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.list('activities', {
            type: 'str'
          });
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().add({
        activities: ['bingo', 'mingo', 'lingo']
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.lrange("" + PREFIX + ":pl:" + id + ":activities", 0, -1, function(err, res) {
          expect(err).toBe(null);
          expect(res.length).toBe(3);
          expect(res[0]).toBe('lingo');
          expect(res[1]).toBe('mingo');
          expect(res[2]).toBe('bingo');
          return done();
        });
      });
    });
  });

  describe('Substracting from Records', function() {
    return it('Should decerment numbers in a record, using add', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.num('bingo');
          this.num('mexico');
          this.num('points');
          this.num('nicaragua');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player().add({
        bingo: 5,
        mexico: 7,
        points: 15,
        nicaragua: 234345
      }).exec(function(err, res, id) {
        expect(err).toBe(null);
        expect(id).not.toBe(null);
        return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
          expect(err).toBe(null);
          expect(res.bingo).toBe('5');
          expect(res.mexico).toBe('7');
          expect(res.points).toBe('15');
          expect(res.nicaragua).toBe('234345');
          return player(id).add({
            bingo: -1,
            mexico: -2,
            points: -3,
            nicaragua: -4
          }).exec(function(err, res, id) {
            expect(err).toBe(null);
            expect(id).not.toBe(null);
            return r.hgetall("" + PREFIX + ":pl:" + id, function(err, res) {
              expect(err).toBe(null);
              expect(res.bingo).toBe('4');
              expect(res.mexico).toBe('5');
              expect(res.points).toBe('12');
              expect(res.nicaragua).toBe('234341');
              return done();
            });
          });
        });
      });
    });
  });

  describe('Delete', function() {
    return it('Remove Everything', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('bingo');
          this.list('stream');
          this.zset('bonga');
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('id').set({
        bingo: 'pinaaa',
        stream: [1, 2, 3, 4, 43, 53, 45, 345, 345],
        bonga: [5, 'donga']
      }).exec(function() {
        return player('id')["delete"](function(err, res, id) {
          expect(err).toBe(null);
          expect(id).toBe('id');
          return r.multi().exists("" + PREFIX + ":pl:id").exists("" + PREFIX + ":pl:id:stream").exists("" + PREFIX + ":pl:id:bonga").exec(function(err, res) {
            expect(res[0]).toBe(0);
            expect(res[1]).toBe(0);
            expect(res[2]).toBe(0);
            return done();
          });
        });
      });
    });
  });

  describe('Validation', function() {
    return it('Validate Strings', function(done) {
      var Player, player;
      Player = (function(_super) {

        __extends(Player, _super);

        function Player() {
          this.str('name');
          this.validate('name', function(s) {
            if (s === 'almog') {
              return true;
            } else {
              return {
                message: 'String should be almog'
              };
            }
          });
        }

        return Player;

      })(Orpheus);
      player = Player.create();
      return player('15').set({
        name: 'almog'
      }).exec(function(err, res, id) {
        expect(res[0]).toBe(1);
        return player('15').set({
          name: 'chiko'
        }).exec(function(err, res, id) {
          expect(err[0].type).toBe('validation');
          expect(err[0].toString()).toBe('Error: String should be almog');
          return done();
        });
      });
    });
  });

}).call(this);
