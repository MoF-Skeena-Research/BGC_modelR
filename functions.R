library(data.table)
library(sf)
library(dplyr)
library(tidyr)

# Custom error handling function for data validation
data_value_error <- function(message) stop(paste("Data Value Error:", message))

align <- function(bounds) {
  # Align bounds with a raster by rounding to nearest 100m and shifting
  ll <- sapply(bounds[1:2], function(b) (floor(b / 100) * 100) - 12.5)
  ur <- sapply(bounds[3:4], function(b) (ceiling(b / 100) * 100) + 87.5)
  c(ll[1], ll[2], ur[1], ur[2])
}

load_tables <- function(config) {
  data <- list()
  
  # Remap columns
  elevation_column_remap <- c("classnm" = "class_name", 
                              "neut_low" = "neutral_low", 
                              "neut_high" = "neutral_high", 
                              "polygonnbr" = "polygon_number")
  rules_column_remap <- c("polygonnbr" = "polygon_number")
  
  # Load elevation data
  if (grepl(".csv$", config$elevation)) {
    data$elevation <- fread(config$elevation)
  } else if (grepl(".xls[x]?$", config$elevation)) {
    data$elevation <- readxl::read_excel(config$elevation, col_names = TRUE)
  }
  
  # Rename and format elevation columns
  setnames(data$elevation, tolower(names(data$elevation)))
  setnames(data$elevation, elevation_column_remap)
  
  data$elevation <- data$elevation %>% 
    mutate(across(c(cool_low, cool_high, neutral_low, neutral_high, warm_low, warm_high, polygon_number), as.integer)) %>%
    select(beclabel, cool_low, cool_high, neutral_low, neutral_high, warm_low, warm_high, polygon_number)
  
  # Load becmaster
  a <- fread(config$becmaster, select = 1:5, col.names = c("becvalue", "zone", "subzone", "variant", "phase"))
  becmaster_required_cols <- c("becvalue", "zone", "subzone", "variant", "phase")
  
  if (any(!becmaster_required_cols %in% names(a))) {
    missing_cols <- paste(setdiff(becmaster_required_cols, names(a)), collapse = ", ")
    data_value_error(paste("Missing columns:", missing_cols))
  }
  
  if (any(duplicated(a$becvalue))) {
    dups <- a$becvalue[duplicated(a$becvalue)]
    data_value_error(paste("Duplicated becvalue IDs:", paste(dups, collapse = ", ")))
  }
  
  a$beclabel <- paste0(str_pad(a$zone, 4, "right"), str_pad(a$subzone, 3, "right"), a$variant, a$phase)
  a <- a[, .(becvalue, beclabel = trimws(beclabel))]
  
  # Join becvalue to elevation
  data$elevation <- merge(data$elevation, a, by = "beclabel", all.x = TRUE)
  
  if (any(is.na(data$elevation$becvalue))) {
    badlabels <- unique(data$elevation[is.na(becvalue), beclabel])
    data_value_error(paste("Invalid beclabel(s) in elevation:", paste(badlabels, collapse = ", ")))
  }
  
  # Load rule polygons
  data$rulepolys <- st_read(config$rulepolys_file, layer = config$rulepolys_layer)
  if (is.na(st_crs(data$rulepolys))) {
    data_value_error("CRS is not defined for rule polygons.")
  }
  
  if (st_crs(data$rulepolys) != st_crs(3005)) {
    data$rulepolys <- st_transform(data$rulepolys, 3005)
  }
  
  return(data)
}
validate_data <- function(data) {
  rulepolynums <- unique(data$rulepolys$polygon_number)
  elevpolynums <- unique(data$elevation$polygon_number)
  
  if (!all(rulepolynums %in% elevpolynums) || !all(elevpolynums %in% rulepolynums)) {
    missing_in_rules <- setdiff(rulepolynums, elevpolynums)
    missing_in_elev <- setdiff(elevpolynums, rulepolynums)
    data_value_error(paste("Polygon numbers mismatch between rulepolys and elevation tables:",
                           "\n  Missing in rulepolys:", paste(missing_in_rules, collapse = ", "),
                           "\n  Missing in elevation:", paste(missing_in_elev, collapse = ", ")))
  }
  
  # Validate elevation continuity
  data$elevation %>% 
    group_by(polygon_number) %>% 
    summarise(across(starts_with("cool"), list), across(starts_with("neutral"), list), across(starts_with("warm"), list)) %>%
    rowwise() %>%
    do({
      elev_values <- sort(c(unlist(c_across(starts_with("cool"))), 
                            unlist(c_across(starts_with("neutral"))), 
                            unlist(c_across(starts_with("warm")))))
      unique_vals <- unique(elev_values)
      if (length(unique_vals) != length(elev_values) / 2) {
        data_value_error(paste("Discontinuous elevations for polygon_number", .$polygon_number))
      }
      NULL
    })
}

multi2single <- function(gdf) {
  single <- gdf %>% filter(st_geometry_type(geometry) == "POLYGON")
  multi <- gdf %>% filter(st_geometry_type(geometry) == "MULTIPOLYGON")
  
  if (nrow(multi) > 0) {
    split_polys <- multi %>%
      rowwise() %>%
      do(data.frame(geometry = st_cast(.$geometry, "POLYGON"), 
                    st_drop_geometry(.)))
    single <- rbind(single, split_polys)
  }
  
  single
}


bbox2gdf <- function(bbox) {
  bb_polygon <- st_polygon(list(rbind(
    c(bbox[1], bbox[4]),
    c(bbox[3], bbox[4]),
    c(bbox[3], bbox[2]),
    c(bbox[1], bbox[2]),
    c(bbox[1], bbox[4])
  )))
  
  st_sf(geometry = st_sfc(bb_polygon), crs = 3005)
}

