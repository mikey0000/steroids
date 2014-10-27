class Usage

  constructor: (@opts={}) ->

  run: ->
    Help = require "./Help"

    Help.usage.header()
    Help.usage.compact()

    Help.usage.extended() if @opts.extended

    Help.usage.footer()

module.exports = Usage
