## ---- include = FALSE---------------------------------------------------------
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

options("quiet"= 2) # for a little reporting
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
options("quiet"= 2) #just the progress bar
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
#  gr <- s2::s2_data_countries(c("Greenland", "Canada", "Iceland"))
#  gr_buffer_s2 <- s2::s2_buffer_cells(gr, distance = 50000, max_cells = 20000) %>%
#     st_as_sfc()
#  m_s2 <- ggplot(st_transform(gr_buffer_s2, crs_Atlantic)) + geom_sf(fill = "grey40") +
#     geom_sf(data = st_transform(st_as_sfc(gr), crs_Atlantic))
#  
#  sf_use_s2(FALSE) # to be sure
#  gr_transf <- gr %>%
#     st_as_sfc() %>%
#     st_transform(crs_Atlantic)
#  gr_t_buffer <- gr_transf %>%
#     st_buffer(dist = 50000)
#  m_old <- ggplot(gr_t_buffer) + geom_sf(fill = "grey40") + geom_sf(data = gr_transf)
#  
#  cowplot::plot_grid(m_old, m_s2, labels = c("bad", "good"),
#                     ncol = 1)
#  

## ----Island Example, fig.width=7, eval = FALSE--------------------------------
#  sf::sf_use_s2(TRUE)
#  hires <- sf::st_as_sf(rnaturalearthhires::countries10) %>%
#    filter(NAME %in% c("Greenland", "Canada", "Iceland"))
#  hires_buffer_s2 <- s2::s2_buffer_cells(hires, distance = 50000, max_cells = 20000) %>%
#     st_as_sfc()
#  m_hires <- ggplot(st_transform(hires_buffer_s2, crs_Atlantic)) +
#    geom_sf(fill = "grey40") +
#     geom_sf(data = st_transform(hires, crs_Atlantic))
#  
#  cowplot::plot_grid(m_s2, m_hires, labels = c("good", "better"),
#                     ncol = 1)
#  

## ----echo = FALSE-------------------------------------------------------------
#for tidiness remove the temp file now 
# this is only for passing CRAN tests - you don't need to do it.
unlink(full_filename)


