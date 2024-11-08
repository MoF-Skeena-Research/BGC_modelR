# This defaultconfig list in R will act similarly to the Python dictionary in defaultconfig. 
# You can then access or update values as needed, such as with defaultconfig$rulepolys_file
# or by modifying individual settings as defaultconfig$temp_folder <- "new_folder_path".

# Load necessary libraries
library(tempdir)

# Define default configuration as a list
defaultconfig <- list(
  rulepolys_file = "becmodel.gdb",
  rulepolys_layer = "rulepolys",
  elevation = "elevation.xls",
  becmaster = NULL,
  dem = NULL,
  temp_folder = tempdir(),
  out_file = "becmodel.shp",
  out_layer = "becmodel",
  cell_size_metres = 50,
  cell_connectivity = 1,
  noise_removal_threshold_ha = 10,
  high_elevation_removal_threshold_ha = 100,
  aspect_neutral_slope_threshold_percent = 15,
  aspect_midpoint_cool_degrees = 0,
  aspect_midpoint_neutral_east_degrees = 90,
  aspect_midpoint_warm_degrees = 200,
  aspect_midpoint_neutral_west_degrees = 290,
  majority_filter_steep_slope_threshold_percent = 25,
  majority_filter_size_slope_low_metres = 250,
  majority_filter_size_slope_steep_metres = 150,
  expand_bounds_metres = 2000,
  high_elevation_removal_threshold_alpine = c("BAFA", "CMA", "IMA"),
  high_elevation_removal_threshold_parkland = c("p", "s"),
  high_elevation_removal_threshold_woodland = c("w")
)

# Print to confirm structure
print(defaultconfig)
