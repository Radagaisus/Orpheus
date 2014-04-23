// Generated by CoffeeScript 1.7.1
(function() {
  this.num = {
    greater_than: {
      fn: function(a, b) {
        return a > b;
      },
      msg: function(a, b) {
        return "" + a + " must be greater than " + b + ".";
      }
    },
    greater_than_or_equal_to: {
      fn: function(a, b) {
        return a >= b;
      },
      msg: function(a, b) {
        return "" + a + " must be greater than or equal to " + b + ".";
      }
    },
    equal_to: {
      fn: function(a, b) {
        return a === b;
      },
      msg: function(a, b) {
        return "" + a + " must be equal to " + b + ".";
      }
    },
    less_than: {
      fn: function(a, b) {
        return a < b;
      },
      msg: function(a, b) {
        return "" + a + " must be less than " + b + ".";
      }
    },
    less_than_or_equal_to: {
      fn: function(a, b) {
        return a <= b;
      },
      msg: function(a, b) {
        return "" + a + " must be less than or equal to " + b + ".";
      }
    },
    odd: {
      fn: function(a) {
        return !!(a % 2);
      },
      msg: function(a) {
        return "" + a + " must be odd.";
      }
    },
    even: {
      fn: function(a) {
        return !(a % 2);
      },
      msg: function(a) {
        return "" + a + " must be even.";
      }
    },
    only_integer: {
      fn: function(n) {
        return typeof n === 'number' && parseFloat(n) === parseInt(n, 10) && !isNaN(n) && isFinite(n);
      },
      msg: function(n) {
        return "" + n + " must be an integer.";
      }
    }
  };

  this.size = {
    minimum: {
      fn: function(len, min) {
        return len >= min;
      },
      msg: function(field, len, min) {
        return "'" + field + "' length is " + len + ". Must be bigger than " + min + ".";
      }
    },
    maximum: {
      fn: function(len, max) {
        return len <= max;
      },
      msg: function(field, len, max) {
        return "'" + field + "' length is " + len + ". Must be smaller than " + max + ".";
      }
    },
    "in": {
      fn: function(len, range) {
        return (range[0] <= len && len <= range[1]);
      },
      msg: function(field, len, range) {
        return "'" + field + "' length is " + len + ". Must be between " + range[0] + " and " + range[1] + ".";
      }
    },
    is: {
      fn: function(len1, len2) {
        return len1 === len2;
      },
      msg: function(field, len1, len2) {
        return "'" + field + "' length is " + len1 + ". Must be " + len2 + ".";
      }
    }
  };

}).call(this);
