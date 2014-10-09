Help = require "./steroids/Help"
Grunt = require "./steroids/Grunt"
paths = require "./steroids/paths"

argv = require('optimist').argv
util = require "util"
open = require "open"
fs = require("fs")
chalk = require "chalk"

class Steroids

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
    if firstOption in ["connect", "deploy", "simulator"]
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
        console.log @version.formattedVersion()

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

      when "debug"
        Help.legacy.debugweinre()

      when "weinre"
        Help.legacy.debugweinre()

      when "simulator"
        Simulator = require "./steroids/Simulator"

        #TODO: why is it like this?
        steroidsCli.simulator.run
          deviceType: argv.deviceType

      when "connect"
        Project = require "./steroids/Project"
        Serve = require "./steroids/Serve"
        Server = require "./steroids/Server"
        PortChecker = require "./steroids/PortChecker"

        @port = if argv.port
          argv.port
        else
          4567

        if argv.serve
          servePort = if argv.servePort
            argv.servePort
          else
            4000

          serve = new Serve servePort,
            platform: argv.platform

          serve.start()

        checker = new PortChecker
          port: @port
          autorun: true
          onOpen: ()=>
            console.log "Error: port #{@port} is already in use. Make sure there is no other program or that 'steroids connect' is not running on this port."
            process.exit(1)

          onClosed: ()=>
            project = new Project
            project.push
              onFailure: =>
                steroidsCli.debug "Cannot continue starting server, the push failed."
              onSuccess: =>
                BuildServer = require "./steroids/servers/BuildServer"

                server = Server.start
                  port: @port
                  callback: ()=>
                    global.steroidsCli.server = server

                    buildServer = new BuildServer
                                        server: server
                                        path: "/"
                                        port: @port

                    server.mount(buildServer)

                    Prompt = require("./steroids/Prompt")
                    prompt = new Prompt
                      context: @
                      buildServer: buildServer

                    unless argv.qrcode is false
                      QRCode = require "./steroids/QRCode"
                      QRCode.showLocal
                        port: @port

                      util.log "Waiting for the client to connect, scan the QR code visible in your browser ..."

                    setInterval () ->
                      activeClients = 0;
                      needsRefresh = false

                      for ip, client of buildServer.clients
                        delta = Date.now() - client.lastSeen

                        if (delta > 2000)
                          needsRefresh = true
                          delete buildServer.clients[ip]
                          console.log ""
                          util.log "Client disconnected: #{client.ipAddress} - #{client.userAgent}"
                        else if client.new
                          needsRefresh = true
                          activeClients++
                          client.new = false

                          console.log ""
                          util.log "New client: #{client.ipAddress} - #{client.userAgent}"
                        else
                          activeClients++

                      if needsRefresh
                        util.log "Number of clients connected: #{activeClients}"
                        prompt.refresh()

                    , 1000


                    if argv.watch
                      steroidsCli.debug "Starting FS watcher"
                      Watcher = require("./steroids/fs/watcher")

                      project = new Project

                      refreshAndPrompt = =>
                        console.log ""
                        util.log "File system change detected, pushing code to connected devices ..."
                        project.make
                          onSuccess: =>
                            if argv.livereload
                              buildServer.triggerLiveReload()
                            else
                              prompt.refresh()

                      if argv.watchExclude?
                        excludePaths = steroidsCli.config.getCurrent().watch.exclude.concat(argv.watchExclude.split(","))
                      else
                        excludePaths = steroidsCli.config.getCurrent().watch.exclude

                      watcher = new Watcher
                        excludePaths: excludePaths
                        onCreate: refreshAndPrompt
                        onUpdate: refreshAndPrompt
                        onDelete: (file) =>
                          steroidsCli.debug "Deleted watched file #{file}"

                      watcher.watch("./app")
                      watcher.watch("./www")
                      watcher.watch("./config")

                    prompt.connectLoop()

      when "serve"
        Help.legacy.serve()

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
        Server = require "./steroids/Server"
        Login = require "./steroids/Login"

        Help.logo()

        if Login.authTokenExists()
          util.log "Already logged in."
          return

        util.log "Starting login process"

        @port = if argv.port
          argv.port
        else
          13303

        server = Server.start
          port: @port
          callback: ()=>
            login = new Login
              server: server
              port: @port
            login.authorize()

      when "logout"
        Login = require "./steroids/Login"

        Help.logo()

        unless Login.authTokenExists()
          util.log "Try logging in before you try logging out."
          return

        Login.removeAuthToken()

        Help.loggedOut()


      when "deploy"
        Login = require "./steroids/Login"

        Project = require "./steroids/Project"

        Help.logo()

        unless Login.authTokenExists()
          util.log "ERROR: no authentication found, run steroids login first."
          process.exit 1

        util.log "Building application locally"

        project = new Project
        project.make
          onSuccess: =>
            project.package
              onSuccess: =>
                Deploy = require "./steroids/Deploy"
                deploy = new Deploy(otherOptions)
                deploy.uploadToCloud ()=>
                  # all complete
                  process.exit 0
              onFailure: =>
                console.log "Cannot create package, cloud deploy not possible."
          onFailure: =>
            console.log "Cannot build project locally, cloud deploy not possible."

      when "chat"
        console.log "Chat is deprecated, please visit forums at http://forums.appgyver.com"

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
    global.steroidsCli = new Steroids
      debug: argv.debug
      argv: argv

    steroidsCli.execute()

  Help: Help
  paths: paths
