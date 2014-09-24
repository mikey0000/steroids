module.exports =
  getLocationFromRouteOrUrl: (routeObject) ->
    if routeObject.route?
      "http://localhost/app/#{routeObject.route}.html"
    else if routeObject.url?
      routeObject.url
    else
      ""
