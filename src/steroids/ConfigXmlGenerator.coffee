fs = require "fs"
xmlbuilder = require "xmlbuilder"
_ = require "lodash"

paths = require "./paths"
Config = require "./project/config"

module.exports = class ConfigXmlGenerator

  constructor: ->

  writeConfigAndroidXml: ->
    config = new Config()
    currentConfig = config.getCurrent()

    unless fs.existsSync paths.application.configs.configAndroidXml
      xml = @constructAndroidXmlFromConfig(currentConfig)

      fs.writeFileSync paths.application.dist.configAndroidXml, xml


  writeConfigIosXml: ->
    config = new Config()
    currentConfig = config.getCurrent()

    unless fs.existsSync paths.application.configs.configIosXml
      xml = @constructIosXmlFromConfig(currentConfig)

      fs.writeFileSync paths.application.dist.configIosXml, xml

  constructIosXmlFromConfig: (config)->
    root = xmlbuilder.create("widget")
    root.ele "access", origin: "*"

    allowedNamespaces = [
      'webView'
      'splashscreen'
    ]
    for namespaceName, namespace in config when namespaceName in allowedNamespaces
      for key, value in namespace
        {key, value} = @getLegacyProperty(namespaceName, key, value)
        root.ele "preference",
          name: key
          value: value

    root.end
      pretty: true

  constructAndroidXmlFromConfig: (config)->
    root = xmlbuilder.create("widget")
    root.ele "access", origin: "*"
    
    # autohide
    {key, value} = @getLegacyProperty(
      'splashscreen'
      'autohide'
      config['splashscreen']['autohide']
    )
    root.ele "preference",
      name: key
      value: value

    # fullscreen
    root.ele "preference",
      name: "fullscreen"
      value: "false"

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

      when "splashscreen"
        switch key
          when "autohide"
            key: "AutoHideSplashScreen"
            value: value
