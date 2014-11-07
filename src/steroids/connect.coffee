class Connect

  constructor:(opts={}) ->
    @port = opts.port
    @showQRCode = opts.qrcode
    @watch = opts.watch
    @livereload = opts.livereload
    @watchExclude = opts.watchExclude

  run: (opts={}) =>
    return new Promise (resolve, reject) =>
      Simulator = require "./Simulator"
      simulatorForKillingIt = new Simulator
      simulatorForKillingIt.killall()

      Genymotion = require "./emulate/genymotion"
      genymotionForKillingIt = new Genymotion
      genymotionForKillingIt.killall()
      .then ->
        steroidsCli.debug "Killed genymotion"

      Project = require "./Project"
      @project = new Project

      @project.push
        onFailure: reject
        onSuccess: =>
          @startServer()
          .then resolve

  startServer: ()=>
    return new Promise (resolve, reject) =>
      Server = require "./Server"
      BuildServer = require "./servers/BuildServer"

      @server = Server.start
        port: @port
        callback: ()=>
          global.steroidsCli.server = @server

          @buildServer = new BuildServer
            server: @server
            path: "/"
            port: @port

          @server.mount(@buildServer)

          @startPrompt()
          .then resolve

  startPrompt: ()=>
    return new Promise (resolve, reject) =>
      Prompt = require "./Prompt"
      @prompt = new Prompt
        context: @
        buildServer: @buildServer

      unless @showQRCode is false
        QRCode = require "./QRCode"
        QRCode.showLocal
          port: @port

        steroidsCli.debug "connect", "Waiting for the client to connect, scan the QR code visible in your browser ..."

      refreshLoop = ()=>
        activeClients = 0;
        needsRefresh = false

        for ip, client of @buildServer.clients
          delta = Date.now() - client.lastSeen

          if (delta > 4000)
            needsRefresh = true
            delete @buildServer.clients[ip]
            steroidsCli.debug "connect", "Client disconnected: #{client.ipAddress} - #{client.userAgent}"
          else if client.new
            needsRefresh = true
            activeClients++
            client.new = false

            steroidsCli.debug "connect", "New client: #{client.ipAddress} - #{client.userAgent}"
          else
            activeClients++

        if needsRefresh
          steroidsCli.debug "connect", "Number of clients connected: #{activeClients}"
          @prompt.refresh()

      setInterval refreshLoop, 1000

      if @watch
        @startWatcher()
        .then resolve
      else
        resolve()

  startWatcher: ()=>
    return new Promise (resolve, reject) =>
      Watcher = require "./fs/watcher"
      appWatcher = new Watcher
        path: "app"
        ignored: @watchExclude

      wwwWatcher = new Watcher
        path: "www"
        ignored: @watchExclude

      configWatcher = new Watcher
        path: "config"
        ignored: @watchExclude

      Project = require "./Project"
      project = new Project

      liveReloadUpdate = =>
        project.make
          onSuccess: =>
            @buildServer.triggerLiveReload()
            prompt.refresh()
          onFailure: (error)=>
            if error.message.match /Parse error/ # coffee parser errors are of class Error
              console.log "Error parsing application configuration files: #{error.message}"
            else
              throw error

      appWatcher.on ["add", "change", "unlink"], (path)=>
        liveReloadUpdate()

      wwwWatcher.on ["add", "change", "unlink"], (path)=>
        liveReloadUpdate()

      configWatcher.on ["add", "change", "unlink"], (path)=>
        project.make
          onSuccess: =>
            project.package
              onSuccess: =>
                @prompt.refresh()
          onFailure: (error)=>
              if error.message.match /Parse error/ # coffee parser errors are of class Error
                console.log "Error parsing application configuration files: #{error.message}"
              else
                throw error

      Help = require "./Help"
      Help.connect()

      @prompt.connectLoop()

      resolve()


module.exports = Connect
