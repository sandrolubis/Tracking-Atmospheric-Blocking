# blocking_detection
Tracking blocking regions based on Masato et al. (2013, Journal of Climate)

 Assumptions
1. Geopotential height data are read from a netcdf file
2. In geopotential file, it has time, latitude and longitude dimensions
   all of these dimensions are NAMED and have associated coordinate
; .. variables
; 3. Data cover all longitudes (without cyclic point
; .. i.e. the first longitude =/= the final longitude
; 4. Data are continuous in time

;How to run
; ===================================================================

ncl main.ncl
