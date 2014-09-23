paths = require "./paths"

module.exports = class SupersonicConfig

  constructor: ->
    configPath = paths.application.configs.app
    lol = require configPath
    @setDefaults(lol)

  getCurrent: () ->
    return "lol"

  setDefaults: ->
    # set defaults here
