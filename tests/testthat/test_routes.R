NZ_coast <- hm_get_test("coast")
NZ_buffer30 <- hm_get_test("buffer")
NZ_Buller_buffer40 <- hm_get_test("nofly")
NZ_grid <- hm_get_test("grid")
NZ_routes <- hm_get_test("route")
# given some solaris CMD Check errors (old GDAl?)
# redefine crs_Pacific
#same as Robinson, but centred on long +180
# crs_Pacific <- sf::st_crs("+proj=robin +lon_0=180 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")


# quick summary for test purposes
summarise_routes_for_test <- function(r){
  r |>
    # wkt is machine-dependent so just extract length/area
    dplyr::mutate(dplyr::across(c(gc, crow), st_length),
         gc_length = gc) |>
    dplyr::mutate(envelope = sf::st_area(envelope)) |>
    sf::st_drop_geometry() |>
    dplyr::group_by(fullRouteID) |>
    # test on key outputs, not on detail of table
    dplyr::summarise(dplyr::across(c(time_h, gc_length, crow, envelope), \(x) sum(x, na.rm = TRUE))) |>
    # and round to 3 sig figs
    dplyr::mutate(dplyr::across(c(time_h, gc_length, crow, envelope), \(x) signif(x, 3)))
}

test_that("Route envelope", {
  ac <- make_aircraft(warn = FALSE)
  ap <- make_airports(warn = FALSE)
  z <- make_route_envelope(ac[1,], make_AP2("EGLL","KJFK", ap),
                           envelope_points = 50)
  expect_type(z, "list")
  expect_s3_class(z, "sfc_POLYGON")
  expect_gte(nrow(as.matrix(z[[1]])), 50)
})

# avoid testing against stored result, since that's sensitive to
# adding fields later, which is likely
# so - add fields but don't fiddle with the list of test routes ;-)
test_that("Route summary", {
  ap <- make_airports(crs=crs_Pacific, warn = FALSE)
  rs1 <- summarise_routes(NZ_routes, ap)
  expect_equal(rs1[1, ]$refuel_ap, "NZWN")
  expect_equal(rs1[2, ]$M084_h, 1.69)
  expect_equal(rs1[2, ]$advantage_h, -0.87)
  expect_equal(rs1[3, ]$sea_dist_frac, 0.70)
  expect_equal(rs1[4, ]$n_phases, 5)
  expect_equal(rs1[2, ]$n_accel, 2)
  expect_equal(rs1[2, ]$ave_fly_speed_M, 0.80)
  expect_equal(rs1[1, ]$fly_time_h, 1.67)
  expect_equal(rs1[4, ]$circuity, 0.21)
  expect_true(rs1[5, ]$best)
  expect_true(is.na(rs1[6, ]$time_h))
  # parameter behaviour?
  rs2 <- summarise_routes(NZ_routes, ap, arrdep_h = 1.0)
  expect_equal(rs2[1, ]$advantage_h - rs1[1, ]$advantage_h, 0.5)
})

test_that("find_leg catches input error",{
  old_verbosity <- getOption("himach.verbosity", default=0)
  options("himach.verbosity" = 0) #for no reporting
  hm_clean_cache() #start without cache
  # need to load some of the built-in data
  aircraft <- make_aircraft(warn = FALSE)
  # airports <- make_airports()
  airports <- make_airports(crs = crs_Pacific, warn = FALSE)
  options("himach.verbosity" = old_verbosity)
  # for visual check:
  # ggplot(NZ_buffer30) + geom_sf() + geom_sf(data = routes$gc)

  # fail nicely with bad aircraft index
  expect_error(find_leg(aircraft[400,],
                        make_AP2("NZAA","NZCH",airports),
                        fat_map = NZ_buffer30,
                        route_grid = NZ_grid,
                        ap_loc = airports),
                 "Aircraft invalid")
})


test_that("find_route works with subsonic option",{
  old_verbosity <- getOption("himach.verbosity", default = 0)
  options("himach.verbosity" = 3) #for full reporting
  hm_clean_cache() #start without cache
  # need to load some of the built-in data
  aircraft <- make_aircraft(warn = FALSE)
  airports <- make_airports(crs = crs_Pacific, warn = FALSE)

  # test with parallel subsonic aircraft
  # just ditch the output
  suppressMessages(
    routes <- find_route(aircraft[1, ],
                       make_AP2("NZGS", "NZDN", airports),
                       fat_map = NZ_buffer30,
                       route_grid = NZ_grid,
                       ap_loc = airports,
                       cf_subsonic = aircraft[3, ]) |>
       summarise_routes_for_test()
  )
  # test a couple of rows
  expect_snapshot_value(routes, style = "serialize",
                     tolerance = 0.05)

  # and test saving of cache
  tmp_dir <- tempdir()
  full_filename <- hm_save_cache("test_that", NZ_grid, aircraft, path = tmp_dir)
  hm_clean_cache() #empty cache
  hm_load_cache(full_filename)
  expect_true(length(.hm_cache) == 2)
  expect_true(length(.hm_cache$route_cache) == 2)
  expect_true(length(.hm_cache$star_cache) == 4)
  unlink(full_filename) # remove the temporary cache file to pass CRAN test

  options("himach.verbosity" = old_verbosity)
})

test_that("Find multiple routes for multiple aircraft",{
  old_verbosity <- getOption("himach.verbosity", default=0)
  options("himach.verbosity" = 0) #for no reporting
  hm_clean_cache() #start without cache
  # need to load some of the built-in data
  aircraft <- make_aircraft(warn = FALSE)
  airports <- make_airports(crs = crs_Pacific, warn = FALSE)
  refuel_ap <- airports |>
    filter(APICAO == "NZWN")

  ap2 <- as.data.frame(matrix(c("NZAA","NZCH","NZAA","NZDN"),
                              ncol = 2, byrow = TRUE), stringsAsFactors = FALSE)
  ac <- aircraft[c(1,4), ]$id

  invisible(capture.output(
    routes <- find_routes(ac, ap2, aircraft, airports,
                        fat_map = NZ_buffer30,
                        route_grid = NZ_grid,
                        refuel = refuel_ap) |>
      summarise_routes_for_test()
  ))
  # just test a sample
  expect_snapshot_value(routes, style = "serialize",
                     tolerance = 0.05)

  # and again with a no-fly zone - and just one AP2
  invisible(capture.output(
    routes <- find_routes(ac, ap2[1, ], aircraft, airports,
                          fat_map = NZ_buffer30,
                          route_grid = NZ_grid,
                          refuel = refuel_ap,
                          avoid = NZ_Buller_buffer40)  |>
      summarise_routes_for_test()
  ))
  # check one row from each route
  expect_snapshot_value(routes, style = "serialize",
                     tolerance = 0.05)

  # check for faulty airports
  ap2 <- as.data.frame(matrix(c("ZZZZ", "NZAA", "NZCH", "NZAA"),
                              ncol = 2, byrow = TRUE), stringsAsFactors = FALSE)
  expect_error(find_routes(ac, ap2, aircraft, airports,
                             fat_map = NZ_buffer30,
                             route_grid = NZ_grid),
               "unknown")

  options("himach.verbosity" = old_verbosity)
})
