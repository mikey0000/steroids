Either = require "data.either"
fs = require "fs"
_ = require "lodash"

paths = require "./paths"
LegacyConfig = require "./LegacyConfig"
SupersonicConfig = require "./SupersonicConfig"

module.exports = class Config

  constructor: ->
    @version = if fs.existsSync(paths.application.configs.app)
      "supersonic"
    else
      "legacy"

  getCurrent: =>
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
