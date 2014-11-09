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
  PlatformError: class PlatformError extends SteroidsError

  # move this to globals
  simulator: null

  globals:
    genymotion: null
    simulator: null

  constructor: (@options = {}) ->
    Simulator = require "./steroids/Simulator"
    Version = require "./steroids/version/version"
    Config = require "./steroids/Config"

    @simulator = new Simulator
      debug: @options.debug

    @version = new Version
    @pathToSelf = process.argv[1]
    @config = new Config
    @platform = @options.argv.platform || "ios"
    @debugEnabled = @options.debug

    @connect = null

  host:
    os:
      isOSX: ->
        process.platform == "darwin"
      isWindows: ->
        process.platform == "win32"
      isLinux: ->
        process.platform == "linux"


  readApplicationConfig: ->
    applicationConfig = paths.application.configs.application

    if fs.existsSync(applicationConfig)
      contents = fs.readFileSync(applicationConfig).toString()

    return contents

  detectSteroidsProject: ->
    return fs.existsSync(paths.application.configDir) and (fs.existsSync(paths.application.appDir) or fs.existsSync(paths.application.wwwDir))

  debug: (options = {}, other) =>
    message = if other?
      options + ": " + other
    else if options.constructor.name == "String"
      options
    else
      options.message

    message = "#{new Date()} #{message}"

    steroidsCli.debugMessages ||= []
    steroidsCli.debugMessages.push message

    if steroidsCli.options.debug
      process.stdout.cursorTo(0) if process.stdout.cursorTo?
      console.log "[DEBUG]", message


  log: (options) =>

    [tagMessage, message, refresh, prepend, newline] = if options.constructor.name == "String"
      [undefined, options,true, true, true]
    else
      [options.tag, options.message, (options.refresh != false), (options.prepend != false), (options.newline != false)]

    tag = if tagMessage
      "[#{tagMessage}] "
    else
      ""

    prefix = if prepend and @connect?.prompt?
      prepend = "\n"
    else
      ""

    suffix = if newline
      suffix = "\n"
    else
      ""

    util.print "#{prefix}#{tag}#{message}#{suffix}"

    if refresh and @connect?.prompt?
      @connect?.prompt?.refresh()

  ensureProjectIfNeededFor: (command, otherOptions) ->
    commands = [
      "push"
      "make"
      "package"
      "connect"
      "update"
      "generate"
      "deploy"
      "debug"
      "emulate"
      "data"
    ]

    if command in commands
      return if @detectSteroidsProject()

      steroidsCli.log "Error: command '#{command}' requires to be run in a Steroids project directory."
      process.exit(1)

  execute: =>
    [firstOption, otherOptions...] = argv._

    if argv.version
      firstOption = "version"

    if firstOption not in ["emulate", "debug"] and argv.help
      firstOption = "usage"

    unless steroidsCli.host.os.isOSX()
      wrongPlatform = true
      if firstOption == "emulate" and otherOptions[0] == "ios"
        steroidsCli.log "Error: iOS Simulator requires Mac OS X."
      else
        wrongPlatform = false

      process.exit(1) if wrongPlatform


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
        Data = require "./steroids/Data"

        data = new Data
        switch otherOptions[0]
          when "init"
            data.init()

          #TODO impl
          # when "reset"
          #   providers = new Providers
          #   providers.removeDatabase()

          when "manage"
            data.manage()

          when "sync"
            data.sync()

          else
            Help.dataUsage()

      when "version"
        steroidsCli.version.run()

      when "create"
        folder = otherOptions[0]

        unless folder
          steroidsCli.log "Usage: steroids create <directoryName>"
          process.exit(1)

        ProjectCreator = require("./steroids/ProjectCreator")
        projectCreator = new ProjectCreator

        projectCreator.generate(folder).then ->
          projectCreator.update().then ->
            steroidsCli.log "\n#{chalk.bold.green('\nSuccesfully created a new Steroids project!')}"
          .catch (err) ->
            steroidsCli.log err.message
            process.exit 1

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
        console.log "see: steroids emulate"

      when "connect"

        Connect = require "./steroids/connect"

        port = if argv.port
          argv.port
        else
          4567

        watchExclude = if argv.watchExclude
          argv.watchExclude.split(",")
        else
          []

        watchEnabled = !(argv.watch == false)
        livereloadEnabled = !(argv.livereload == false)

        @connect = new Connect
          port: port
          watch: watchEnabled
          livereload: livereloadEnabled
          watchExclude: watchExclude
          qrcode: argv.qrcode

        @connect.run()
        .catch (error)=>
          if error.message.match /Parse error/ # coffee parser errors are of class Error
            console.log "Error parsing application configuration files: #{error.message}"
            console.log "Fix the syntax error and re-run the steroids connect command"
          else
            throw error

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

        login.run().then () =>
          Help.loggedIn()
          process.exit(0)

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
        console.log "see: steroids debug"

      when "emulate"
        switch otherOptions[0]
          when "android"

            Android = require "./steroids/emulate/android"
            android = new Android()
            android.run().catch (error) ->
              Help.error()
              steroidsCli.log
                message: error.message

          when "ios"

            if argv.devices
              steroidsCli.simulator.getDevicesAndSDKs()
              .then (devices)->
                for device in devices
                  steroidsCli.log "#{device.name}#{chalk.grey('@'+device.sdks)}"
            else
              steroidsCli.simulator.run
                device: argv.device

          when "genymotion"
            Genymotion = require "./steroids/emulate/genymotion"
            genymotion = new Genymotion()
            genymotion.run()

          else
            Usage = require "./steroids/usage"
            usage = new Usage
            usage.emulate()

      when "debug"

        switch otherOptions[0]
          when "safari"
            SafariDebug = require "./steroids/SafariDebug"
            safariDebug = new SafariDebug
            safariDebug.run
              path: argv.location

          when "chrome"
            ChromeDebug = require "./steroids/debug/chrome"
            chromeDebug = new ChromeDebug
            chromeDebug.run().then ->
              steroidsCli.log "Opened chrome://inspect in Google Chrome"

          when "weinre"
            console.log "Not implemented yet"

          else
            Usage = require "./steroids/usage"
            usage = new Usage
            usage.debug()

      when "log"

        switch otherOptions[0]
          when "steroids"
            SteroidsLog = require "./steroids/log/steroids_log"
            steroidsLog = new SteroidsLog
            steroidsLog.run()

          when "logcat"
            LogCat = require "./steroids/log/logcat"
            logCat = new LogCat

            if argv.tail
              logCat.run
                tail: true
            else
              logCat.run()
              .then (logLines) ->
                for line in logLines
                  do (line) ->
                    steroidsCli.log line

          else
            Usage = require "./steroids/usage"
            usage = new Usage
            usage.log()

      when "__watch"

        Watcher = require "./steroids/fs/watcher"
        watcher = new Watcher
          path: otherOptions[0]

        for event in ["change", "add", "unlink", "addDir", "unlinkDir", "error"]
          do (event) ->
            watcher.on event, (path, stats) ->
              console.log event, path, stats


      else
        Usage = require "./steroids/usage"
        usage = new Usage
          extended: argv.help?

        usage.run()

module.exports =
  run: ->
    domain = require "domain"
    d = domain.create()

    d.on 'error', (err) ->

      if err.name == "PlatformError"
        steroidsCli.log "Operating system not supported"
      else

        console.log """
        Debug Log:
        #{steroidsCli.debugMessages.join("\n")}

        Error with: steroids #{process.argv[2]}

        #{err.stack}

        Runtime information:

        \tplatform: #{process.platform}\tnode path: #{process.execPath}
        \tarch: #{process.arch}\t\tnode version: #{process.version}

        \tcwd: #{process.cwd()}

        Please send the above output to contact@appgyver.com
          (Also if possible, re-run the same command with --debug and please send that output too)
        """

    d.run ->
      global.steroidsCli = new Steroids
        debug: argv.debug
        argv: argv

      steroidsCli.execute()

  Help: Help
  paths: paths
