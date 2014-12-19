open = require "open"
URL = require "url"

paths = require "./paths"
Deploy = require "./Deploy"

Provider = require "./data/Provider"
SandboxDB = require "./data/SandboxDB"
dataHelpers = require "./data/Helpers"

dataManagerURL = "https://data.appgyver.com/browser/projects"

class Data
  @DataError: class DataError extends steroidsCli.SteroidsError

  constructor: ->
    @sandboxDB = new SandboxDB

  init: ->
    return new Promise (resolve, reject) =>
      Updater = require "./Updater"
      updater = new Updater
      updater.check
        from: "data"

      if steroidsCli.projectType is "cordova"
        reject new DataError "Data is currently only available for Supersonic projects."
        return

      steroidsCli.debug "DATA", "Initializing data for project"

      deploy = new Deploy
      unless deploy.cloudConfig?
        steroidsCli.debug "DATA", "Initializing data for project failed: not deployed"
        reject new DataError "Project must be deployed first"
        return

      @sandboxDB.get()
      .then => Provider.forBackend(@sandboxDB)
      .then resolve

  sync: ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DATA", "Synchronizing data configuration from cloud to project"

      steroidsCli.debug "DATA", "Reading data configuration from cloud"
      Provider.readRamlFromCloud()
      .then (raml)=>
        steroidsCli.debug "DATA", "Writing data configuration to project"
        Provider.writeRamlToFile(raml)
      .then resolve

  getConfig: ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DATA", "Getting data configuration from disk"
      result = {}

      @sandboxDB.readFromFile().then =>
        steroidsCli.debug "DATA", "Got data configuration from disk"
        result.initialized = @sandboxDB.apikey?
        result.sandboxdb = @sandboxDB.configurationKeysForProxy()

        resolve(result)

  manage: (provider_name, params) ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DATA", "Opening Data manager from CLI"

      appId = dataHelpers.getAppId()
      open URL.format "#{dataManagerURL}/#{appId}"
      resolve()


module.exports = Data
