Server = require "../Server"
Converter = require "../Converter"
util = require "util"
request = require "request"
semver = require "semver"
chalk = require "chalk"
winston = require "winston"
bodyParser = require "body-parser"
express = require "express"

fs = require "fs"
Paths = require "../paths"

Updater = require "../Updater"


class ClientResolver

  constructor: (@request) ->

  ipInInterfaces: (ip, interfaces) =>
    for iface in interfaces
      return true if iface.ip == ip

    return false

  resolve: =>
    ios = @request.headers["user-agent"].match("iPhone|iPad|iPod")?
    android = ios == false

    interfaces = steroidsCli.server.interfaces()
    simulator = @ipInInterfaces(@request.ip, interfaces)

    clientVersion = @request.query["client_version"]

    clientVersionMatch = @request.headers["user-agent"].match(/AppGyverSteroids\/([^\s]+)/)
    clientVersion = clientVersionMatch[1] if clientVersionMatch

    if android
      androidVersionMatch = @request.headers["user-agent"].match(/Android (\d+\.\d+\.\d+)\;/)
      osVersion = androidVersionMatch[1] if androidVersionMatch

    if ios
      iosVersionMatch = @request.headers["user-agent"].match(/(iPod|iPad|iPhone) OS ([^\s]*)/)
      device = iosVersionMatch[1] if iosVersionMatch
      osVersion = iosVersionMatch[2] if iosVersionMatch

    return {
      isIOS: ios
      isSimulator: simulator
      isAndroid: android
      version: clientVersion
      osVersion: osVersion
      device: device
    }

class BuildServer extends Server

  constructor: (@options) ->
    @converter = new Converter Paths.application.configs.application
    @clients = {}
    winston.add winston.transports.File, { filename: Paths.application.logFile }
    winston.remove winston.transports.Console

    super(@options)

    @app.use express.static(Paths.connectStaticFiles)
    @app.use bodyParser.json()

  setRoutes: =>
    @app.get "/", (req, res) =>
      res.redirect("/__appgyver/index.html")

    @app.get "/appgyver/api/applications/1.json", (req, res) =>

      config = @converter.configToAnkaFormat()

      zipObject =
        url: "#{req.protocol}://#{req.hostname}:#{@options.port}/appgyver/zips/project.zip"

      config.archives.push zipObject

      res.json config

    @app.get "/appgyver/zips/project.zip", (req, res)->
      res.sendFile Paths.temporaryZip

    @app.get "/refresh_client_events?:timestamp", (req, res)=>
      res.header "Access-Control-Allow-Origin", "*"
      res.header('Content-Type', 'text/event-stream')
      res.header('Cache-Control', 'no-cache')
      res.header('Connection', 'keep-alive')

      timestamp = key for key,val of req.query

      id = setInterval ()->

        if fs.existsSync Paths.temporaryZip
          filestamp = fs.lstatSync(Paths.temporaryZip).mtime.getTime()
        else
          filestamp = 0

        if parseInt(filestamp,10) > parseInt(timestamp,10)
          res.write 'event: refresh\ndata: true\n\n'
        else
          res.write 'event: refresh\ndata: false\n\n'

      , 1000

      res.on "close", ()->
        clearInterval id

    @app.get "/__appgyver/cloud_config", (req, res) =>
      res.header "Access-Control-Allow-Origin", "*"
      res.header "Access-Control-Allow-Headers", "Content-Type"

      if fs.existsSync Paths.application.configs.cloud
        cloudConfig = require Paths.application.configs.cloud
        res.json cloudConfig
      else
        error = "Could not find config/cloud.json. Please run $ steroids deploy."

        res.status(404).json {error: error}

    @app.options "/__appgyver/logger", (req, res) =>
      res.header "Access-Control-Allow-Origin", "*"
      res.header "Access-Control-Allow-Headers", "Content-Type"

      res.end ''

    @app.get "/__appgyver/logger", (req, res) =>
      res.header "Access-Control-Allow-Origin", "*"
      res.header "Access-Control-Allow-Headers", "Content-Type"

      options = {}

      winston.query options, (err, results) ->
        if (err)
          throw err

        res.send results.file
        res.end ''

    @app.post "/__appgyver/logger", (req, res) =>
      res.header "Access-Control-Allow-Origin", "*"
      res.header "Access-Control-Allow-Headers", "Content-Type"
      res.end ''

      logMsg = req.body

      #unused stuff coming in from Steroids.js:
      #  logMsg.date, .screen_id, .layer_id, .view_id

      logLevel = logMsg.level || "info"
      message = logMsg.message
      metadata =
        view: logMsg.location
        deviceName: logMsg.deviceName || null # not provided by steroids.js yet
        blob: logMsg.deviceName || null # expandable extra info for the message

      winston.log logLevel, message, metadata


    @app.get "/refresh_client?:timestamp", (req, res) =>

      res.header "Access-Control-Allow-Origin", "*"

      clientResolver = new ClientResolver(req)
      resolvedClient = clientResolver.resolve()

      client = if @clients[req.ip]
        @clients[req.ip]
      else

        platform = if resolvedClient.isAndroid
          "android"
        else
          "ios"

        updater = new Updater()
        updater.checkClient
          platform: platform
          version: resolvedClient.version
          simulator: resolvedClient.isSimulator
          osVersion: resolvedClient.osVersion
          device: resolvedClient.device

        {
          ipAddress: req.ip
          firstSeen: Date.now()
          userAgent: req.headers["user-agent"]
          new: true
        }

      client.lastSeen = Date.now()
      @clients[req.ip] = client

      timestamp = key for key,val of req.query

      if fs.existsSync Paths.temporaryZip
        filestamp = fs.lstatSync(Paths.temporaryZip).mtime.getTime()
      else
        filestamp = 0

      if parseInt(filestamp,10) > parseInt(timestamp,10)
        res.send "true"
      else
        res.send "false"


module.exports = BuildServer
