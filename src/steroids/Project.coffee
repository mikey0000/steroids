sbawn = require "./sbawn"
util = require "util"
paths = require "./paths"
chalk = require "chalk"
fs = require "fs"
Help = require "./Help"
ApplicationConfigUpdater = require "./ApplicationConfigUpdater"
AppSettings = require "./AppSettings"
Grunt = require "./Grunt"
ConfigXmlGenerator = require "./ConfigXmlGenerator"

class Project

  constructor: (@options={}) ->
    @config = steroidsCli.config.getCurrent()

  initialize: (options={}) =>
    options.onSuccess()

  push: (options = {}) =>
    steroidsCli.debug "Starting push"

    @make
      onFailure: options.onFailure
      onSuccess: =>
        @package
          onSuccess: () =>
            options.onSuccess.call() if options.onSuccess?

  preMake: (options = {}) =>
    if @config.hooks.preMake.cmd and @config.hooks.preMake.args

      util.log "preMake starting: #{@config.hooks.preMake.cmd} with #{@config.hooks.preMake.args}"

      preMakeSbawn = sbawn
        cmd: @config.hooks.preMake.cmd
        args: @config.hooks.preMake.args
        stdout: true
        stderr: true

      steroidsCli.debug "preMake spawned"

      preMakeSbawn.on "exit", =>
        errorCode = preMakeSbawn.code

        if errorCode == 137 and @config.hooks.preMake.cmd == "grunt"
          util.log "command was grunt build which exists with 137 when success, setting error code to 0"
          errorCode = 0

        util.log "preMake done"

        if errorCode == 0
          options.onSuccess.call() if options.onSuccess?
        else
          util.log "preMake resulted in error code: #{errorCode}"
          options.onFailure.call() if options.onFailure?

    else
      options.onSuccess.call() if options.onSuccess?


  postMake: (options = {}) =>
    if @config.hooks.postMake.cmd and @config.hooks.postMake.args

      util.log "postMake started"

      postMakeSbawn = sbawn
        cmd: @config.hooks.postMake.cmd
        args: @config.hooks.postMake.args
        stdout: true
        stderr: true

      postMakeSbawn.on "exit", =>
        util.log "postMake done"

        options.onSuccess.call() if options.onSuccess?
    else
      options.onSuccess.call() if options.onSuccess?

  makeOnly: (options = {}) => # without hooks

    applicationConfigUpdater = new ApplicationConfigUpdater

    applicationConfigUpdater.ensureNodeModulesDir().then( =>

      steroidsCli.debug "Running Grunt tasks..."

      grunt = new Grunt()
      grunt.run {tasks: ["default"]}, =>
        unless steroidsCli.options.argv.noSettingsJson == true
          @createSettingsJson()
        @createConfigXml()
        options.onSuccess.call() if options.onSuccess?

    ).fail (errorMessage)->
      Help.error()
      console.log errorMessage
      process.exit(1)

  make: (options = {}) => # with pre- and post-make hooks

    steroidsCli.debug "Making with hooks."

    try
      @config = steroidsCli.config.getCurrent()
    catch e
      options.onFailure(e) if options.onFailure?
      return

    @preMake
      onFailure: options.onFailure
      onSuccess: =>
        @makeOnly
          onFailure: options.onFailure
          onSuccess: =>
            @postMake options

  package: (options = {}) =>
    steroidsCli.debug "Spawning steroids package"

    packageSbawn = sbawn
      cmd: steroidsCli.pathToSelf
      args: ["package"]
      stdout: true
      stderr: true

    packageSbawn.on "exit", =>

      steroidsCli.debug "package exited with code #{packageSbawn.code}"

      if packageSbawn.code == 0
        options.onSuccess() if options.onSuccess
      else
        options.onFailure() if options.onFailure

  createSettingsJson: ->
    appSettings = new AppSettings()
    steroidsCli.debug "Creating dist/__appgyver_settings.json..."
    appSettings.createJSONFile()

  createConfigXml: ->
    configXmlGenerator = new ConfigXmlGenerator()
    steroidsCli.debug "Creating dist/config.ios.xml..."
    configXmlGenerator.writeConfigXml()


module.exports = Project
