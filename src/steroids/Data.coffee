open = require "open"
URL = require "url"

Providers = require "./Providers"
SandboxDB = require "./SandboxDB"
dataHelpers = require "./dataHelpers"

dataManagerURL = "https://data.appgyver.com/browser/projects"

class Data
  @DataError: class DataError extends steroidsCli.SteroidsError

  constructor: ->
    @sandboxDB = new SandboxDB
    @providers = new Providers

  init: ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DATA", "Initializing data for project"

      @sandboxDB.get()
      .then => @providers.get(@sandboxDB)
      .then resolve

  manage: (provider_name, params) ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DATA", "Opening Data manager from CLI"

      appId = dataHelpers.getAppId()
      open URL.format "#{dataManagerURL}/#{appId}"
      resolve()


module.exports = Data
