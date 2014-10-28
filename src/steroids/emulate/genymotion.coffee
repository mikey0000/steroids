sbawn = require "../sbawn"

class Genymotion

  constructor: ->

  run: (opts = {})->

    @killall().then ->

      cmd = "/Applications/Genymotion.app/Contents/MacOS/player"
      args = ["--vm-name", "Google Nexus 10 - 4.4.4 - API 19 - 2560x1600"]

      @genymotionPlayerSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else true
        stderr: if opts.stderr? then opts.stderr else true

  killall: =>
    new Promise (resolve) ->
      killGenymotion = sbawn
        cmd: "/usr/bin/pkill"
        args: ["-9", "player"]

      killGenymotion.on "exit", ->
        console.log "Genymotion killed"
        resolve()

module.exports = Genymotion
