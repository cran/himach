## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
#the libraries needed for the vignette are
library(himach)
library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(ggplot2)
library(sf)

# and we'll load a full set of test data
NZ_coast <- hm_get_test("coast")
NZ_buffer30 <- hm_get_test("buffer")
NZ_Buller_buffer40 <- hm_get_test("nofly")
NZ_grid <- hm_get_test("grid")
NZ_routes <- hm_get_test("route")

## ----cache saving-------------------------------------------------------------
hm_clean_cache() #start without cache

# need to load some of the built-in data for this example
aircraft <- make_aircraft(warn = FALSE)
airports <- make_airports(crs = crs_Pacific)

options("himach.verbosity"= 2) # for a little reporting
# how long does it take with an empty cache?
system.time(
  routes <- find_route(aircraft[1, ],
                       make_AP2("NZAA", "NZDN", airports),
                       fat_map = NZ_buffer30,
                       route_grid = NZ_grid,
                       ap_loc = airports)
)

# test saving of cache to a disposable directory
tmp_dir <- tempdir()
# for convenience, hm_save_cache gives the full name, including path
full_filename <- hm_save_cache("test_v", NZ_grid, aircraft, path = tmp_dir)

#empty cache - just to demonstrate the re-loading
# this isn't part of your normal workflow!
hm_clean_cache() 
# but normally a session will begin with loading a cache like this
hm_load_cache(full_filename)

# how long does it take with a cache?
system.time(
  routes <- find_route(aircraft[1, ],
                       make_AP2("NZAA", "NZDN", airports),
                       fat_map = NZ_buffer30,
                       route_grid = NZ_grid,
                       ap_loc = airports)
)


# if you want to see a map
# map_routes(NZ_coast, routes, crs_Pacific, fat_map = NZ_buffer30, simplify_km = 2)

## ----cache housekeeping-------------------------------------------------------
# for this example, add a second route to the cache
routes <- find_route(aircraft[2, ],
                       make_AP2("NZAA", "NZDN", airports),
                       fat_map = NZ_buffer30,
                       route_grid = NZ_grid,
                       ap_loc = airports)
# save the cache, which has NZAA-NZDN for 2 aircraft now
hm_save_cache("test_v", NZ_grid, aircraft, path = tmp_dir)

#now do housekeeping
load(full_filename) # filename from the previous chunk
ls(route_cache) # show the contents, just for information
# we want to delete instances of aircraft with ID that includes 'M22'
z <- ls(route_cache, pattern="M22") |> as.list()
length(route_cache) # before deletion
do.call(rm, z, envir = route_cache) # delete the M22 items
length(route_cache) #after deletion, 1 less
# then repeat for star_cache
z <- ls(star_cache, pattern="M22") |> as.list()
length(star_cache)
do.call(rm, z, envir = star_cache)
length(star_cache)
# then save the result (you might want to change the filename, or backup the old cache beforehand)
save("route_cache", "star_cache", file = full_filename)

## ----define_density_plot_fn---------------------------------------------------

hm_latlong_density <- function(rt, # route dataset created earlier
                               ll = "lat", #lat or long chart?
                               # frequency data, either 1 or
                               # dataset with at least 5 columns
                               freq = 1, 
                               # 2 for joining
                               join_var = c("acID", "routeID"),
                               # 1 for value
                               freq_var = flights_w,
                               freq_lab = "Hours per week",
                               # and 2 for faceting
                               facet_rows = vars(year), #or use NULL
                               facet_cols = vars(scen_ord, acID),
                               # other plot configuration elements
                               bar_deg = 3, # width of bar plotted in degrees
                               resolution_deg = 1, # granularity of analysis, keep small
                               # ignore when flights are stationary (refuelling)
                               drop_zero = TRUE,
                               # return a graph, or a set of data
                               return_data = FALSE){
  # graph of lat or long?
  sel_coord <- ifelse(ll |> 
                        stringr::str_to_upper() |> 
                        stringr::str_sub(1, 2) == "LA",
                      2, 1)
  coord_label <- ifelse(sel_coord == 2, "Latitude (deg)", "Longitude (deg)")
  
  rt <- rt |>
    ungroup() |> #just in case supplied dataset is grouped
    # standard route dataset will have all of these
    # each row is a great circle segment
    # in particular time_h is the flight time in hours for the segment
    select(phase, phaseID, gc, acID, routeID, speed_kph, time_h, crow) |>
    mutate(seg = row_number()) # note this is ungrouped
  # this is a graph of flight time, so ignore time spent on the ground refuelling
  if (drop_zero) rt <- rt |>
    filter(speed_kph > 0)
  
  if (is.data.frame(freq)) {
    # zoom in on the variables we need
    freq <- freq |>
      ungroup() |>
      select(all_of(join_var), {{freq_var}}, scen_ord, year)
    
    rt <- rt |>
      inner_join(freq, by = join_var, relationship = "many-to-many")
  } else {
    rt <- rt |>
      mutate(flights_w = 1)
    facet_rows <- NULL
    facet_cols <- vars(acID)
  }
  
  # split the great circle arcs into the graph resolution
  rt <- rt |>
    # ensure fine resolution
    sf::st_segmentize(units::set_units(resolution_deg, degree)) |>
    # drop the sf geometry, without dropping the gc column
    sf::st_set_geometry("crow") |> # we only kept this to sacrifice it here
    sf::st_drop_geometry() |>
    group_by(across(!gc)) |> #don't want to lose any var in the reframe
    # the reframe is to pull out either lat or long coordinate
    reframe(coord = st_coordinates(gc)[ , sel_coord]) |>
    group_by(across(any_of(c("seg", "scen_ord", "year")))) |> # now keep one entry per segment/resolution
    # drop the last row if there's more than one, because we want to count line segments really
    slice(1:max(1, n()-1)) |>
    #round to the graph resolution
    mutate(coord = resolution_deg * floor(coord / resolution_deg)) |>
    distinct() |>
    # time_h is the flight time in hours for the great circle segment
    # now shared, after st_segmentize, amongst n() subsegments
    mutate(time_h = {{freq_var}} * time_h / n(),
           bar_coord = bar_deg * round(coord/bar_deg))
  
  # then use geom_bar to add up the times, across all flights
  g <- ggplot(rt, aes(bar_coord,
                      fill = phase,
                      weight = time_h)) +
    geom_bar()  +
    facet_grid(rows = facet_rows, cols = facet_cols) +
    labs(y = freq_lab, x = coord_label)
  # orient appropriately for long or lat
  if (sel_coord == 2) g <- g +
    coord_flip()
  
  if (return_data) return(rt) else return(g)
}

## ----density_examples, fig.width=7--------------------------------------------
# simple case with default 1 flight/week frequency
hm_latlong_density(NZ_routes, facet_rows = NULL, facet_cols = vars(acID),
                   bar_deg = 0.5, resolution_deg = 0.1)

# make up a forecast of frequencies
freq_fc <- NZ_routes |> 
  # get the ac & routes we need the forecast for
  select(acID, routeID) |> 
  st_drop_geometry() |> # convert from sf to tibble
  distinct() |> 
  # add in some forecast years
  tidyr::crossing(tibble(year = c(2040L, 2050L))) |> 
  # add in some scenarios
  tidyr::crossing(tibble(scen_ord = ordered(c("low", "base", "high"), 
                                            levels = c("low", "base", "high")))) |> 
  # and some flights per week (that don't make a lot of sense)
  arrange(year, scen_ord) |> 
  mutate(flights_w = row_number()) 
  
hm_latlong_density(NZ_routes, ll = "long", 
                   freq = freq_fc,
                   bar_deg = 0.5, resolution_deg = 0.1)


## ----createBuffer-------------------------------------------------------------
# using your own shp file 
# NZ_Buller <- sf::read_sf("...../territorial-authority-2020-clipped-generalised.shp") %>% 
#     filter(TA2020_V_1 == "Buller District")
# NZ_Buller_u <- sf::st_union(sf::st_simplify(NZ_Buller, dTolerance = 1000))
# NZ_Buller_buffer50 <- sf::st_union(sf::st_buffer(NZ_Buller_u, 50 * 1000))
# attr(NZ_Buller_buffer50, "avoid") <- "Buller+50km"
# the quicker version, using a built-in no fly zone

# this uses data as in the previous code chunk
aircraft <- make_aircraft(warn = FALSE)
airports <- make_airports(crs = crs_Pacific)

# run the same route, but with the avoid region
options("himach.verbosity"= 2) #just the progress bar
ac <- aircraft[c(1, 4), ]$id
routes <- find_routes(ac, 
                      data.frame(ADEP = "NZAA", ADES = "NZDN"),
                      aircraft, airports,
                      fat_map = NZ_buffer30, 
                      route_grid = NZ_grid,
                      cf_subsonic = aircraft[3,],
                      avoid = NZ_Buller_buffer40)

#this shows versions of the legs with and without no-fly
# ls(route_cache, pattern = "NZCH", envir = .hm_cache)

# create route summary
rtes <- summarise_routes(routes, airports)

# draw a basic map
map_routes(NZ_coast, routes, crs_Pacific, fat_map = NZ_buffer30,
          avoid_map = NZ_Buller_buffer40,
          simplify_km = 2)

map_routes(NZ_coast, routes, show_route = "aircraft",
           crs = crs_Pacific, fat_map = NZ_buffer30,
          avoid_map = NZ_Buller_buffer40,
          simplify_km = 2)


## ----buffers in s2, fig.width=7, eval = FALSE---------------------------------
# gr <- s2::s2_data_countries(c("Greenland", "Canada", "Iceland"))
# gr_buffer_s2 <- s2::s2_buffer_cells(gr, distance = 50000, max_cells = 20000) %>%
#    st_as_sfc()
# m_s2 <- ggplot(st_transform(gr_buffer_s2, crs_Atlantic)) + geom_sf(fill = "grey40") +
#    geom_sf(data = st_transform(st_as_sfc(gr), crs_Atlantic))
# 
# sf_use_s2(FALSE) # to be sure
# gr_transf <- gr %>%
#    st_as_sfc() %>%
#    st_transform(crs_Atlantic)
# gr_t_buffer <- gr_transf %>%
#    st_buffer(dist = 50000)
# m_old <- ggplot(gr_t_buffer) + geom_sf(fill = "grey40") + geom_sf(data = gr_transf)
# 
# cowplot::plot_grid(m_old, m_s2, labels = c("bad", "good"),
#                    ncol = 1)
# 

## ----Island Example, fig.width=7, eval = FALSE--------------------------------
# sf::sf_use_s2(TRUE)
# hires <- sf::st_as_sf(rnaturalearthhires::countries10) %>%
#   filter(NAME %in% c("Greenland", "Canada", "Iceland"))
# hires_buffer_s2 <- s2::s2_buffer_cells(hires, distance = 50000, max_cells = 20000) %>%
#    st_as_sfc()
# m_hires <- ggplot(st_transform(hires_buffer_s2, crs_Atlantic)) +
#   geom_sf(fill = "grey40") +
#    geom_sf(data = st_transform(hires, crs_Atlantic))
# 
# cowplot::plot_grid(m_s2, m_hires, labels = c("good", "better"),
#                    ncol = 1)
# 

## ----echo = FALSE-------------------------------------------------------------
#for tidiness remove the temp file now 
# this is only for passing CRAN tests - you don't need to do it.
unlink(full_filename)


