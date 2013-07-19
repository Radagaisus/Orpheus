{spawn, exec} = require 'child_process'
log = console.log
      
task 'bake', "Compiles to JavaScript", ->
  run 'coffee -o dist -c lib/*.coffee'
  run 'cp lib/*.js dist/'
    
task 'test', "Testing using Jasmine-Node", ->
  run 'jasmine-node test/orpheus.spec.coffee --verbose --color --forceexit --coffee'

task 'dev', "Start developing stuff", ->
	run 'npm install'
	run 'jasmine-node test/orpheus.spec.coffee --verbose --color --forceexit --coffee'

run = (args...) ->
  for a in args
    switch typeof a
      when 'string' then command = a
      when 'object'
        if a instanceof Array then params = a
        else options = a
      when 'function' then callback = a
  
  command += ' ' + params.join ' ' if params?
  cmd = spawn '/bin/sh', ['-c', command], options
  cmd.stdout.on 'data', (data) -> process.stdout.write data
  cmd.stderr.on 'data', (data) -> process.stderr.write data
  process.on 'SIGHUP', -> cmd.kill()
  cmd.on 'exit', (code) -> callback() if callback? and code is 0