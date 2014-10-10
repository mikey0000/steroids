class Connect

  constructor:(opts={}) ->
    @port = opts.port
    @showQRCode = opts.qrcode
    @watch = opts.watch
    @livereload = opts.livereload
    @watchExclude = opts.watchExclude

  run: (opts={}) =>
    Project = require "./Project"
    Serve = require "./Serve"
    Server = require "./Server"
    PortChecker = require "./PortChecker"
    util = require "util"

    BuildServer = require "./servers/BuildServer"
    server = Server.start
      port: @port
      callback: ()=>
        global.steroidsCli.server = server

        buildServer = new BuildServer
                            server: server
                            path: "/"
                            port: @port

        server.mount(buildServer)

        Prompt = require("./Prompt")
        prompt = new Prompt
          context: @
          buildServer: buildServer

        unless @showQRCode is false
          QRCode = require "./QRCode"
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


        if @watch
          steroidsCli.debug "Starting FS watcher"
          Watcher = require("./fs/watcher")

          project = new Project

          refreshAndPrompt = =>
            console.log ""
            util.log "File system change detected, pushing code to connected devices ..."
            project.make
              onSuccess: =>
                if @livereload
                  buildServer.triggerLiveReload()
                else
                  prompt.refresh()

          if @watchExclude?
            excludePaths = steroidsCli.config.getCurrent().watch.exclude.concat(@watchExclude.split(","))
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




module.exports = Connect
