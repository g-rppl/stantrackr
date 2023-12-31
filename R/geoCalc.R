# Convert degrees to radians
.toRad <- function(deg) {
  return(deg * pi / 180)
}

# Convert radians to degrees
.toDeg <- function(rad) {
  return(rad * 180 / pi)
}

# Circular difference
.circDiff <- function(x, y) {
  180 - abs(abs(x - y) - 180)
}

# Distance between geographic points
.distGeo <- function(lon1, lat1, lon2, lat2, r = 6378.137) {
  dLon <- .toRad(lon2 - lon1)
  dLat <- .toRad(lat2 - lat1)

  lat1 <- .toRad(lat1)
  lat2 <- .toRad(lat2)

  a <- sin(dLat / 2) * sin(dLat / 2) +
    sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  return(r * c)
}

# Destination given bearing (direction) and distance
.destPoint <- function(lon1, lat1, b, d, r = 6378.137) {
  lon1 <- .toRad(lon1)
  lat1 <- .toRad(lat1)
  a <- .toRad(b)

  lat2 <- asin(sin(lat1) * cos(d / r) + cos(lat1) * sin(d / r) * cos(a))
  lon2 <- lon1 + atan2(
    sin(a) * sin(d / r) * cos(lat1),
    cos(d / r) - sin(lat1) * sin(lat2)
  )
  return(cbind(
    lon = .toDeg(lon2),
    lat = .toDeg(lat2)
  ))
}

# Calculate lagged distances in metres
.distance <- function(x) {
  dist <- rep(NA, nrow(x))
  for (i in 2:nrow(x)) {
    dist[i] <- .distGeo(
      x$mean.lon[i], x$mean.lat[i],
      x$mean.lon[i - 1], x$mean.lat[i - 1]
    )
  }
  return(dist * 1e3)
}
