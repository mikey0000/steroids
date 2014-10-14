Help = require "./steroids/Help"
paths = require "./steroids/paths"

argv = require('optimist').argv
util = require "util"
open = require "open"
fs = require("fs")
chalk = require "chalk"

global.Promise = require("bluebird")
Promise.onPossiblyUnhandledRejection (e, promise) ->
  throw e


class SteroidsError extends Error
  constructor: (message)->
    Error.call @
    Error.captureStackTrace(@, @constructor)
    @name = @constructor.name
    @message = message

class Steroids

  SteroidsError: SteroidsError

  simulator: null

  constructor: (@options = {}) ->
    Simulator = require "./steroids/Simulator"
    Version = require "./steroids/Version"
    Config = require "./steroids/Config"

    @simulator = new Simulator
      debug: @options.debug

    @version = new Version
    @pathToSelf = process.argv[1]
    @config = new Config
    @platform = @options.argv.platform || "ios"

  readApplicationConfig: ->
    applicationConfig = paths.application.configs.application

    if fs.existsSync(applicationConfig)
      contents = fs.readFileSync(applicationConfig).toString()

    return contents

  detectSteroidsProject: ->
    return fs.existsSync(paths.application.configDir) and (fs.existsSync(paths.application.appDir) or fs.existsSync(paths.application.wwwDir))

  debug: (options = {}) =>
    return unless steroidsCli.options.debug

    message = if options.constructor.name == "String"
      options
    else
      options.message

    console.log "[DEBUG]", message


  ensureProjectIfNeededFor: (command, otherOptions) ->
    if command in ["push", "make", "package", "simulator", "connect", "update", "generate", "deploy"]

      return if @detectSteroidsProject()
      return if command == "generate" and otherOptions.length == 0    # displays usage

      console.log """
        Error: command '#{command}' requires to be run in a Steroids project directory.
      """

      process.exit(1)

  execute: =>
    [firstOption, otherOptions...] = argv._

    if argv.version
      firstOption = "version"

    @ensureProjectIfNeededFor(firstOption, otherOptions)

    if firstOption in ["connect", "create"]
      Help.logo() unless argv.noLogo

    Login = require("./steroids/Login")
    if firstOption in ["connect", "deploy", "simulator", "logout"]
      unless Login.authTokenExists()
        console.log """

        You must be logged in, log in with:

        \t$ steroids login

        """
        process.exit 1

    switch firstOption

      when "data"
        Providers = require "./steroids/Providers"
        Data = require "./steroids/Data"

        if otherOptions[0] is "init"
          data = new Data
          data.init()

        else if otherOptions[0] is "reset"
          providers = new Providers
          providers.removeDatabase()

        else if otherOptions[0] is "resources:list"
          providers = new Providers
          providers.resourcesForSandbox()

        else if otherOptions[0] is "resources:add"
          otherOptions = otherOptions.slice(1)
          unless otherOptions?.length > 1
            console.log "Usage: steroids data resources:add <resourceName> <columnName>:<columnType>"
            process.exit 1

          providers = new Providers
          providers.addResource(otherOptions).fail (error) =>
            Help.error()
            console.log(
              """
              Could not add resource.

              Error message: #{error}
              """
            )

        else if otherOptions[0] is "resources:remove"
          otherOptions = otherOptions.slice(1)
          unless otherOptions?.length is 1
            console.log "Usage: steroids data resources:remove <resourceName>"
            process.exit 1

          providers = new Providers
          providers.removeResource(otherOptions[0]).fail (error)=>
            Help.error()
            console.log error

        else if otherOptions[0] is "manage"
          data = new Data
          data.manage()

        else if otherOptions[0] is "scaffold"
          otherOptions = otherOptions.slice(1)
          unless otherOptions?.length is 1
            console.log "Usage: steroids data scaffold <resourceName>"
            process.exit 1

          providers = new Providers
          providers.scaffoldResource(otherOptions[0]).fail (error)=>
            Help.error()
            console.log error

        else
          Help.dataUsage()

      when "version"
        Version = require("./steroids/version")
        version = new Version
        version.run()

      when "create"

        folder = otherOptions[0]

        unless folder

          console.log "Usage: steroids create <directoryName>"

          process.exit(1)

        ProjectCreator = require("./steroids/ProjectCreator")
        projectCreator = new ProjectCreator
          debug: @options.debug

        projectCreator.generate(folder)


      when "push"
        Project = require "./steroids/Project"
        project = new Project
        project.push
          onSuccess: ->
            steroidsCli.debug "steroids make && steroids package ok."

      when "make"
        Project = require "./steroids/Project"
        project = new Project
        project.make()

      when "package"
        Packager = require "./steroids/Packager"

        packager = new Packager

        packager.create()

      when "simulator"
        Simulator = require "./steroids/Simulator"

        #TODO: why is it like this?
        steroidsCli.simulator.run
          deviceType: argv.deviceType

      when "connect"
        Connect = require("./steroids/connect")

        port = if argv.port
          argv.port
        else
          4567

        connect = new Connect
          port: port
          watch = argv.watch
          livereload = argv.livereload
          watchExclude = argv.watchExclude
          qrcode = argv.qrcode

        connect.run()


      when "update"
        Updater = require "./steroids/Updater"
        updater = new Updater
          verbose: false

        updater.check(
          from: "update"
        ).then( ->
          Npm = require "./steroids/Npm"
          npm = new Npm
          npm.install()
        ).then( ->
          Bower = require "./steroids/Bower"
          bower = new Bower
          bower.update()
        )

      when "generate"
        [generatorType, generatorArgs...] = otherOptions

        unless generatorType?
          Help.listGenerators()
          process.exit 0

        Generators = require "./steroids/Generators"

        generatorOptions =
          name: generatorArgs[0]
          otherOptions: generatorArgs

        unless Generators[generatorType]
          console.log "No such generator: #{generatorType}"
          process.exit(1)

        generator = new Generators[generatorType](generatorOptions)

        try
          generator.generate()
        catch error
          throw error unless error.fromSteroids?

          util.log "ERROR: #{error.message}"
          process.exit 1


      when "login"
        Login = require "./steroids/Login"

        Help.logo()

        if Login.authTokenExists()
          util.log "Already logged in."
          return

        port = if argv.port
          argv.port
        else
          13303

        login = new Login
          port: port

        login.run()


      when "logout"
        Logout = require "./steroids/logout"
        logout = new Logout
        logout.run().then () ->
          Help.logo()
          Help.loggedOut()

      when "deploy"
        Deploy = require "./steroids/Deploy"

        deploy = new Deploy()

        deploy.run().then () ->
          util.log "Deployment complete"
          Help.deployCompleted()

      when "safari"
        SafariDebug = require "./steroids/SafariDebug"
        safariDebug = new SafariDebug
        if otherOptions[0]
          safariDebug.open(otherOptions[0])
        else
          Help.safariListingHeader()
          safariDebug.listViews()

      else
        Help.logo() unless argv.noLogo
        Help.usage()


module.exports =
  run: ->
    domain = require "domain"
    d = domain.create()

    d.on 'error', (err) ->
      console.log """
      Error with: steroids #{process.argv[2]}

      #{err.stack}

      Runtime information:

      \tplatform: #{process.platform}\tnode path: #{process.execPath}
      \tarch: #{process.arch}\t\tnode version: #{process.version}

      \tcwd: #{process.cwd()}

      Please send the above output to contact@appgyver.com
      """

    d.run ->
      global.steroidsCli = new Steroids
        debug: argv.debug
        argv: argv

      steroidsCli.execute()

  Help: Help
  paths: paths
