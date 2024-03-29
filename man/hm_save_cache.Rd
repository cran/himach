% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cache.R
\name{hm_save_cache}
\alias{hm_save_cache}
\title{Save route and SID/STAR cache to file}
\usage{
hm_save_cache(id, grid, aircraft, path = "data/")
}
\arguments{
\item{id}{Identifying text, see above. Recommended to use a version number
or date.}

\item{grid}{Your route grid dataset. The \code{grid@name} will be added to
the filename.}

\item{aircraft}{Your aircraft dataset. The \code{attr(aircraft,
"aircraftSet")} will be added to the filename.}

\item{path}{By default \code{"data/"}, where the file will be saved.}
}
\value{
Invisible true
}
\description{
Filename is \code{"route_star_cache_id_XXX.rda"} where "id" is the id
parameter and XXX is made up from the name of the grid (which identifies the
map used) and the 'aircraftSet' attribute of the aircraft dataset (which
identifies the source). This is because the cache should be for a unique
combination of these (and you must have these available, because they were
needed to generate the routes).
}
\examples{
# not run
# hm_save_cache("v2", grid, ac) #save here


}
\seealso{
For more details see the cache section in the vignette:
  \code{vignette("Supersonic_Routes_in_depth", package = "himach")}. or
  \href{../doc/Supersonic_Routes_in_depth.html#cache}{Vignette on caching}
}
