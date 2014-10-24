module.exports =
  parseLocation: (location) ->
    if location.match /^[\w\-]+#[\w\-]+$/
      routeParts = location.split "#"
      "http://localhost/app/#{routeParts[0]}/#{routeParts[1]}.html"
    else
      location
