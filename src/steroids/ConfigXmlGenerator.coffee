fs = require "fs"
xmlbuilder = require "xmlbuilder"
_ = require "lodash"

paths = require "./paths"
Config = require "./Config"

module.exports = class ConfigXmlGenerator

  constructor: ->

  writeConfigXml: ->
    config = new Config()
    config = config.getCurrent()

    xml = @constructXmlFromConfig(config)

    fs.writeFileSync paths.application.dist.configIosXml, xml

  constructXmlFromConfig: (config)->
    root = xmlbuilder.create("widget")
    root.ele "access", origin: "*"

    _.forIn config, (value, key)=>
      switch key
        when "webView"
          namespace = "webView"
        when "keyboard"
          namespace = "keyboard"
        when "splashscreen"
          namespace = "splashscreen"
        else
          namespace = null

      if namespace?
        _.forIn config[namespace], (value, key)=>
          {key, value} = @getLegacyProperty(namespace, key, value)
          root.ele "preference",
            name: key
            value: value

    root.end
      pretty: true

  getLegacyProperty: (namespace, key, value)->
    switch namespace
      when "webView"
        switch key
          when "viewsIgnoreStatusBar"
            key: "ViewIgnoresStatusBar"
            value: value
          when "enableDoubleTapToFocus"
            key: "DisableDoubleTapToFocus"
            value: !value
          when "disableOverscroll"
            key: "DisallowOverscroll"
            value: value
          when "enableViewportScale"
            key: "EnableViewportScale"
            value: value
          when "enablePopGestureRecognition"
            key: "EnablePopGestureRecognition"
            value: value
          when "allowInlineMediaPlayback"
            key: "AllowInlineMediaPlayback"
            value: value
          else
            key: key
            value: value

      when "keyboard"
        switch key
          when "shrinksView"
            key: "KeyboardShrinksView"
            value: value
          when "displayRequiresUserAction"
            key: "DisplayRequiresUserAction"
            value: value
          when "hideAccessoryBar"
            key: "HideKeyboardFormAccessoryBar"
            value: value

      when "splashscreen"
        switch key
          when "autohide"
            key: "AutoHideSplashScreen"
            value: value
