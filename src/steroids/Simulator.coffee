steroidsSimulators = require "steroids-simulators"
spawn = require("child_process").spawn

sbawn = require("./sbawn")
Help = require "./Help"

os = require "os"
paths = require "./paths"

Q = require "q"

class Simulator

  DEFAULT_DEVICE_TYPE: "iphone_retina_4_inch"
  SUPPORTED_DEVICE_TYPES: ["ipad", "ipad_retina", "iphone_retina_3_5_inch", "iphone_retina_4_inch"]

  running: false

  constructor: (@options = {}) ->

  run: (opts={}) =>
    unless os.type() == "Darwin"
      console.log "Error: Simulator requires Mac OS X."
      return false

    @stop()

    @running = true

    cmd = paths.iosSim.path
    args = ["launch", steroidsSimulators.latestSimulatorPath]

    if opts.deviceType?

      # Split into device type and optional, '@'-separated suffix specifying the iOS version (SDK version; e.g., '5.1').
      [ deviceType, iOSVersion ] = opts.deviceType.split('@')

      switch deviceType
        when "ipad"
          args.push "--family", "ipad"
        when "ipad_retina"
          args.push "--family", "ipad", "--retina"
        when "iphone_retina_3_5_inch"
          args.push "--retina"
        when "iphone_retina_4_inch"
          args.push "--retina", "--tall"

      if iOSVersion?
        args.push "--sdk", iOSVersion

    @killall().then( =>
      steroidsCli.debug "Spawning #{cmd}"
      steroidsCli.debug "with params: #{args}"

      @simulatorSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else true
        stderr: if opts.stderr? then opts.stderr else true

      @simulatorSession.on "exit", () =>
        @running = false

        steroidsCli.debug "Killing iOS Simulator ..."

        @killall()

        console.log "PRO TIP: use `steroids [simulator|connect] --deviceType <device>` to specify device type, see `steroids usage` for help."

        return unless ( @simulatorSession.stderr.indexOf('Session could not be started') == 0 )

        Help.attention()
        Help.resetiOSSim()

        setTimeout () =>
          resetSimulator = sbawn
                    cmd: steroidsSimulators.iosSimPath
                    args: ["start"]
                    debug: true
        , 250
    )

  stop: () =>
    @simulatorSession.kill() if @simulatorSession

  killall: ()=>
    deferred = Q.defer()

    killSimulator = sbawn
      cmd: "/usr/bin/pkill"
      args: ["-9", "imulator"]

    killSimulator.on "exit", () =>
      steroidsCli.debug "Killed iOS Simulator."
      deferred.resolve()

    return deferred.promise

module.exports = Simulator
