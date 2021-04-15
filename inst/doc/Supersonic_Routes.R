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
library(s2)
library(rnaturalearthdata)


## ----define aircraft----------------------------------------------------------
# example for your own data - see above for column headings
# aircraft <- read.csv("data/aircraft.csv", stringAsFactors = FALSE)
# aircraft <- make_aircraft(aircraft)
# strongly recommended to record the source file name for later reference
# this works even better if your source file has a date embedded in the name
# attr(aircraft, "aircraftSet") <- "aircraft.csv"

# example if you have no data of your own
aircraft <- make_aircraft()


## ----define airports----------------------------------------------------------
# example for your own data
# airports <- read.csv("data/airports.csv", stringAsFactors = FALSE)
# airports <- make_airports(airports)

# example if you have no data of your own
airports <- make_airports(crs = crs_Pacific) %>% 
  filter(substr(APICAO, 1, 1)=="N") #just New Zealand, and neighbours


## ----define refuel points-----------------------------------------------------
refuel_ap <- airports %>% 
  filter(APICAO=="NZWN")


## ----load_maps----------------------------------------------------------------
# if you are using your own shp file 
# NZ_shp <- sf::read_sf("...../territorial-authority-2020-clipped-generalised.shp")
# NZ_coast <- NZ_shp %>% sf::st_simplify(dTolerance = 1000) %>% sf::st_union()
# NZ_buffer30 <- NZ_coast %>% sf::st_buffer(30 * 1000) %>% sf::st_union()

# The in-built test maps are already in crs_Pacific
# All that remains is to illustrate the land and buffer
ggplot(NZ_buffer30) +
    geom_sf(colour = NA, fill = "grey75")  +
      geom_sf(data = NZ_coast, fill = "grey90", colour = NA)+
    theme_minimal()

# a quicker way to do all of this is to use map_routes, with no routes
map_routes(NZ_coast, fat_map = NZ_buffer30, crs = crs_Pacific)


## ----mapswiths2---------------------------------------------------------------
# you really want to use rnaturalearthhires::countries10
# but that's heavy for this vignette
map_NZ <- rnaturalearthdata::countries50 %>%
   st_as_sf() %>%
   filter(name == "New Zealand")
# use attributes to track where this came from
attr(map_NZ, "source") <- "rnaturalearthdata::countries50"
attr(map_NZ, "Antarctic") <- FALSE
attr(map_NZ, "simplify_m") <- NA

# using s2 for buffering
NZ_plus30 <- map_NZ %>%
   st_as_s2() %>%
   s2::s2_buffer_cells(distance = 30000, max_cells = 1000) %>%
   st_as_sfc() 
# again, use attributes to record the metadata
attr(NZ_plus30,"buffer_m") <- 30000
attr(NZ_plus30,"max_cells") <- 1000

# and then simplify for plotting
# just give 1 example here
map_NZ_2k <- map_NZ %>%
   st_as_s2() %>%
   s2::s2_simplify(tolerance = 2000) %>%
   st_as_sfc() 
attr(map_NZ_2k, "simplify_m") <- 2000

# example map, himach::map_routes but without any routes
map_routes(map_NZ_2k, fat_map = NZ_plus30, crs = crs_Pacific)

## ----construct_grid-----------------------------------------------------------
target_km <- 150
system.time(
p_grid <- make_route_grid(NZ_buffer30, "NZ lat-long at 150km",
                             target_km = target_km, classify = TRUE,
                         lat_min = -49, lat_max = -32, 
                         long_min = 162, long_max = 182)
)

# whether this map is useful depends on the target_km v the overall size of the map
ggplot(NZ_buffer30) +
    geom_sf(colour = NA, fill = "grey75")  +
      geom_sf(data = NZ_coast, fill = "grey90", colour = NA) +
  geom_sf(data = p_grid@lattice,
          aes(geometry=geometry), colour="lightblue", size = 0.2) +

    theme_minimal()


## ----simple_route-------------------------------------------------------------
options("quiet" = 4) #for some output
# from Auckland to Christchurch
ap2 <- make_AP2("NZAA","NZCH",airports)

# normally you do NOT want to do this, but for the vignette we
# work with an empty cache
hm_clean_cache()

routes <- find_route(aircraft[4,], 
                     ap2,
                     fat_map = NZ_buffer30, 
                     route_grid = p_grid, 
                     ap_loc = airports)


## ----find_multiple_routes-----------------------------------------------------
options("quiet" = 2) # anything more than 1 is messy, because of the progress bar
ap2 <- matrix(c("NZAA","NZCH","NZAA","NZDN","NZGS","NZCH"), 
              ncol = 2, byrow = TRUE)
ac <- aircraft[c(1,4), ]$id

routes <- find_routes(ac, ap2, aircraft, airports,
                      fat_map = NZ_buffer30, 
                     route_grid = p_grid,
                     refuel = refuel_ap)


## ----route_summary_and_map----------------------------------------------------
# create route summary
rtes <- summarise_routes(routes, airports)

# draw a basic map
map_routes(NZ_coast, routes, crs = crs_Pacific, fat_map = NZ_buffer30)


