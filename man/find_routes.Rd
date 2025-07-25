% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/routes.R
\name{find_routes}
\alias{find_routes}
\title{Find best routes between airport-pair & aircraft combinations}
\usage{
find_routes(ac_ids, ap2_ids, aircraft, airports, ...)
}
\arguments{
\item{ac_ids}{A vector of aircraft IDs, as in column 'id' from
\code{\link{make_aircraft}}}

\item{ap2_ids}{A 2-column matrix or dataframe of airport pair text IDs}

\item{aircraft}{Specification of the aircraft, see
\code{\link{make_aircraft}}}

\item{airports}{Airport locations as from \code{\link{make_airports}}}

\item{...}{Other parameters, passed to \code{\link{find_route}}.}
}
\value{
Dataframe with details of the routes
}
\description{
\code{find_routes} combines an aircraft and airport-pair list and finds the
best routes between them, refuelling if necessary
}
\details{
This function finds is a wrapper for the single-case function
\code{find_route}. It takes (text) lists of aircraft and airport codes,
combines them, then finds routes for all of these. A 'route' is made up
of one or two 'legs' (airport to airport without intermediate stop).

For more details see \code{\link{find_route}}
}
\examples{
# need to load some of the built-in data
aircraft <- make_aircraft(warn = FALSE)
airports <- make_airports(crs = crs_Pacific)
# get test datasets
NZ_buffer30 <- hm_get_test("buffer")
NZ_grid <- hm_get_test("grid")

options("himach.verbosity" = 4) #for heavy reporting
# from Auckland to Christchurch
ap2 <- make_AP2("NZAA","NZCH",airports)
\dontrun{
routes <- find_route(aircraft[4,],
                    ap2,
                    fat_map = NZ_buffer30,
                    route_grid = NZ_grid,
                    ap_loc = airports)
}

}
