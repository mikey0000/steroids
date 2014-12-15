Either = require "data.either"
fs = require "fs"
_ = require "lodash"

paths = require "../paths"
LegacyConfig = require "./legacy-config"
SupersonicConfig = require "./supersonic-config"
CordovaConfig = require "./cordova-config"

module.exports = class Config

  constructor: ->

  getCurrent: =>
    if true #TODO Acual check
      config = new CordovaConfig()
    else
      config = @eitherSupersonicOrLegacy().fold(
        -> new SupersonicConfig()
        -> new LegacyConfig()
      )

    config.getCurrent()

  eitherSupersonicOrLegacy: ->
    if fs.existsSync(paths.application.configs.app)
      new Either.Left("supersonic")
    else
      new Either.Right("legacy")
