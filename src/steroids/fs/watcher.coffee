class Watcher
  constructor: (@opts={}) ->
    chokidar = require "chokidar"

    @watcher = chokidar.watch @opts.path,
      ignored: (path) =>
        return false unless @opts.ignored

        if path in @opts.ignored
          steroidsCli.debug "watch: ignore #{path}"
          return true
        else
          steroidsCli.debug "watch: monitor #{path}"
          return false

      ignoreInitial: true
      persistent: true

  on: (events, callback) ->
    events = if events.constructor.name == "String"
      [events]
    else
      events

    for event in events
      @watcher.on event, callback



module.exports = Watcher
