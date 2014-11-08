
class SteroidsLog

  constructor: ->
    @winston = require "winston"
    Paths = require "../paths"

    @winston.add @winston.transports.File,
      filename: Paths.application.logFile
      level: 'debug'


  run: =>
    print = (log) =>

    @winston.stream
      start: -1
    .on 'log', (log) ->
      steroidsCli.log "#{log.timestamp} - #{log.level} - #{log.view} - #{log.message}"

module.exports = SteroidsLog
