Help = require "./Help"
paths = require "./paths"
Grunt = require "./Grunt"
Project = require "./Project"

chalk = require "chalk"


class Prompt

  prompt: null

  constructor: (@options) ->
    @prompt = require('prompt')

    @prompt.message = "#{chalk.cyan("AppGyver")} #{chalk.magenta("Steroids")}"
    @prompt.delimiter = " "

    @prompt.start();
    @buildServer = @options.buildServer

  refresh: () =>
    process.stdout.write @prompt.message + @prompt.delimiter + chalk.grey("command  ")

  cleanUp: () =>
    console.log "Shutting down Steroids ..."

    steroidsCli.simulator.stop()

    console.log "... done."

  connectLoop: =>
    onInput = (err, result) =>
      skipLoop = false

      command = if result? and result.command?
        result.command
      else
        "quit"

      [mainCommand, commandOptions...] = command.split(' ')

      switch mainCommand
        when "quit", "exit", "q"
          @cleanUp()

          console.log "Bye"

          process.exit(0)
        when "", "push"
          steroidsCli.log "Updating code on all connected devices ..."
          project = new Project
          project.make
            onSuccess: =>
              if steroidsCli.options.argv.livereload
                @buildServer.triggerLiveReload()
                @refresh()
              else
                project.package
                  onSuccess: =>
                    @refresh()

        when "d", "debug"
          SafariDebug = require "./SafariDebug"
          safariDebug = new SafariDebug => @connectLoop()
          if commandOptions[0]?
            safariDebug.open(commandOptions[0])
          else
            safariDebug.listViews()
          return # Exit now and later let the callback passed to SafarDebug's constructor re-enter the loop once its methods exit.

        when "c", "chrome"
          ChromeDebug = require "./debug/chrome"
          chromeDebug = new ChromeDebug
          chromeDebug.run()

        when "a", "and", "android"
          Android = require "./emulate/android"
          android = new Android
          android.run()

        when "g", "gen", "genymotion"
          Genymotion = require "./emulate/genymotion"
          genymotion = new Genymotion
          genymotion.run()

        when "s", "sim", "simulator"

          device = if commandOptions[0]
            commandOptions[0]
          else if steroidsCli.options.argv.device
            steroidsCli.options.argv.deviceType

          steroidsCli.simulator.run
            device: device

        when "qr", "qr-code", "qrcode"
          QRCode = require "./QRCode"
          QRCode.showLocal
            port: @buildServer.port

        when "e", "edit"
          unless process.env.EDITOR?
            steroidsCli.log "EDITOR environment variable not set"
          else
            sbawn = require "./sbawn"
            editor = sbawn
              cmd: process.env.EDITOR
              args: [paths.applicationDir]

        when "r", "reload"
          project = new Project
          project.make
            onSuccess: =>
              project.package
                onSuccess: =>
                  @refresh()

        when "h", "help", "?", "usage"
          Help.connect()
        else
          skipLoop = true

          sbawn = require "./sbawn"
          cmd = sbawn
            cmd: mainCommand
            cwd: paths.applicationDir
            stdout: true
            stderr: true
            onExit: @connectLoop
            args: commandOptions

      unless skipLoop
        @connectLoop()

    @get
      onInput: onInput



  get: (options)->
    @prompt.get
      properties:
        command:
          message: ""
    , (options.onInput ? @options.onInput?)



module.exports = Prompt
