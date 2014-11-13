class Banner

  @print: (message, speed) ->
    new Promise (resolve, reject) ->

      printter = (chars, speed) ->
        if chars.length == 0
          console.log ""
          resolve()
          return

        char = chars.shift()
        process.stdout.write char

        setTimeout ->
          printter(chars, speed)
        , speed

      printter message.split(""), speed



  constructor: (@options = {}) ->
    @figlet = require "figlet"

    @font = @options.font || 'Graffiti'
    @horizontalLayout = @options.horizontalLayout || 'default'
    @verticalLayout = @options.verticalLayout || 'default'

  makeSync: (opts={}) ->
    text = if opts.constructor.name == "String"
      opts
    else
      opts.text

    output = @figlet.textSync text,
      font: @font
      horizontalLayout: @horizontalLayout
      verticalLayout: @verticalLayout

    output

  availableFonts: =>
    new Promise (resolve, reject) =>
      @figlet.fonts (err, fonts) =>
        if err
          reject err
        else
          resolve fonts

module.exports = Banner
