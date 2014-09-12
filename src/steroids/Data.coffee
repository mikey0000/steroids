Q = require "q"
Bower = require "./Bower"
open = require "open"
URL = require "url"
Providers = require "./Providers"
chalk = require "chalk"
Help = require "./Help"
dataHelpers = require "./dataHelpers"

data_manager_url = "https://data.appgyver.com/browser/projects"

class Data

  constructor: ->

  init: ->
    providers = new Providers
    providers.initDatabase().then( =>
      Help.SUCCESS()
      console.log(
        """
        SandboxDB database successfully initialized for your app!

        """
      )
    ).fail (error)->
      Help.error()
      console.log(
        """
        Could not initialize Steroids Data for your app.

        Error message: #{JSON.stringify(error)}
        """
      )

  manage: (provider_name, params) ->
    appId = dataHelpers.getAppId()
    open URL.format "#{data_manager_url}/#{appId}"

module.exports = Data
