steroidsSimulators = require "steroids-simulators"
spawn = require("child_process").spawn

sbawn = require("./sbawn")
Help = require "./Help"

os = require "os"
paths = require "./paths"

Q = require "q"

class Simulator

  running: false

  constructor: (@options = {}) ->

  getDevicesAndSDKs: () ->
    new Promise (resolve, reject) ->
      showDevicesSession = sbawn
          cmd: paths.iosSim.path
          args: ["showdevicetypes"]

      showDevicesSession.on "exit", ->
        [deviceRows..., crap] = showDevicesSession.stderr.split("\n")

        devices = []
        for deviceRow in deviceRows
          [crap, deviceWithSdks] = deviceRow.split("com.apple.CoreSimulator.SimDeviceType.")
          [device, sdks] = deviceWithSdks.split(", ")
          devices.push
            name: device
            sdks: sdks

        resolve(devices)

  run: (opts={}) =>
    unless os.type() == "Darwin"
      return false

    @stop()
    @running = true

    cmd = paths.iosSim.path
    args = ["launch", steroidsSimulators.latestSimulatorPath]


    device = "iPhone-6"
    iOSVersion = undefined

    if opts.device?
      # Split into device type and optional, '@'-separated suffix specifying the iOS version (SDK version; e.g., '5.1').
      [device, iOSVersion] = opts.device.split('@')


    deviceArg = "com.apple.CoreSimulator.SimDeviceType.#{device}"

    if iOSVersion?
      deviceArg = deviceArg + " ,#{iOSVersion}"

    args.push "--devicetypeid", deviceArg


    @killall().then( =>
      steroidsCli.debug "Spawning #{cmd}"
      steroidsCli.debug "with params: #{args}"

      @simulatorSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @simulatorSession.on "exit", () =>
        @running = false

        steroidsCli.debug "Killing iOS Simulator ..."

        @killall()

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
