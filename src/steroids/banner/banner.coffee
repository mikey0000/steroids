class Banner

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
