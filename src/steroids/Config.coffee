fs = require "fs"
paths = require "./paths"
_ = require "lodash"

LegacyConfig = require "./LegacyConfig"
SupersonicConfig = require "./SupersonicConfig"

ensureFunctions = (f) -> (args...) ->
  if f.length is not args.length
    throw new Error "Assertion failed: expected #{f.length} arguments, got #{args.length} arguments."

  for arg,index in args
    if !_.isFunction arg
      throw new Error "Assertion failed: argument at position #{index} was not a function."

  f args...

class Either

  constructor: ->

  fold: ->


class Left extends Either

  constructor: (@value) ->

  fold: ensureFunctions (callbackLeft, callbackRight) ->
    callbackLeft(@value)

class Right extends Either

  constructor: (@value) ->

  fold: ensureFunctions (callbackLeft, callbackRight) ->
    callbackRight(@value)

module.exports = class Config

  constructor: ->
    @version = if fs.existsSync(paths.application.configs.app)
      "supersonic"
    else
      "legacy"

  getCurrent: =>
    config = @eitherSuperOrLegacy(
      ->
        new SupersonicConfig()
      ->
        new LegacyConfig()
    )

    config.getCurrent()

  eitherSuperOrLegacy: (callbackLeft, callbackRight) =>
    getConfigType = ->
      if fs.existsSync(paths.application.configs.app)
        new Left("supersonic")
      else
        new Right("legacy")

    getConfigType().fold(callbackLeft, callbackRight)
