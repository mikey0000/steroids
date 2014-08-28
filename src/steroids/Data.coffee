Q = require "q"
Bower = require "./Bower"
Providers = require "./Providers"

class Data

  constructor: ->

  installDataJs: ->
    deferred = Q.defer()

    console.log(
      """
      Installing the #{chalk.bold "steroids.data.js"} JavaScript library...


      """
    )

    bower = new Bower
    bower.installPackage("steroids-data").then ->
      deferred.resolve

    deferred.promise

  init: ->
    providers = new Providers

    providers.initDatabase().then( =>
      console.log(
        """
        SandboxDB database successfully initialized for your app!


        """
      )

      @installDataJs()
    ).then(=>
      console.log "steroids.data.js successfully installed!"
    ).fail (error)->
      Help.error()
      console.log(
        """
        Could not initialize Steroids Data for your app.

        Error message: #{error}
        """
      )

module.exports = Data
