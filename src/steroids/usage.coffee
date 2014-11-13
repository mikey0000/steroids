Help = require "./Help"

class Usage

  constructor: (@opts={}) ->

  run: ->
    Help = require "./Help"

    Help.usage.header()
    Help.usage.compact()

    if @opts.extended
      Help.usage.extended()
      Help.usage.create()
      Help.usage.emulate()
      Help.usage.log()
      console.log "\n\nGenerator usage:"
      Help.listGenerators()
      console.log "\n\n"

    Help.usage.footer()

  emulate: ->
    Help.usage.emulate()

  debug: ->
    Help.usage.debug()

  log: ->
    Help.usage.log()

module.exports = Usage
