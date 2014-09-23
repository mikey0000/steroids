module.exports =
  getLocationFromRouteOrUrl: (routeObject) ->
    if routeObject.route?
      "http://localhost/#{routeObject.route}.html"
    else if routeObject.url?
      routeObject.url
    else
      ""
