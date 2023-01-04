; ===================================================================
; Assumptions
; 1. Geopotential height data are read from a netcdf file
; 2. In geopotential file, it has time, latitude and longitude dimensions
; .. all of these dimensions are NAMED and have associated coordinate
; .. variables
; 3. Data cover all longitudes (without cyclic point
; .. i.e. the first longitude =/= the final longitude
; 4. Data are continuous in time
;
; **************************************************************************
; Define directories and the output file name
; **************************************************************************

; GRIDSIZE:   the grid size of data (in degrees)
; ZNAME:      the variable name of geopotential height in the input file(s)
; TIMENAME:   the variable name of time in the input file(s)
; LATNAME:	  the variable name of latitude in the input file(s)
; LONNAME:    the variable name of longitude in the input file(s)


GRIDSIZE 			        = 2.5

ZNAME			  	= "hgt"
TIMENAME			= "time"
LATNAME				= "lat"
LONNAME				= "lon"

; **************************************************************************
; **************************************************************************
; ******************** Define Parameters ***********************************
; **************************************************************************
; **************************************************************************
; Define directories of input and output files

DRAWGRAPH			= False

; **** Specify if the input files have the pressure/level coordinates
; LEVZ: 	  the level to be extracted if the input files have pressure coordinates

ISLEVEL				= True
; ISLEVEL				= False
LEVZ				        = 500.

; **************************************************************************
; LAT1 and LAT2 is the central portion of a region for blocking detection
; A blocking refers to a higher geotential height in the region north than the south
; **************************************************************************

LAT1 				= 40.
LAT2 				= 75.

LATREF1 			= 25.
LATREF2 			= 90.

LATREF1N 			= 40.
LATREF2N 			= 90.

LATREF1C 			       = 25.
LATREF2C 			= 75.

; LATREF1N:LATREF2N MUST BE THE SAME SIZE AS LATREF1C:LATREF2C

; **************************************************************************
; DLAT: the meridional extent of the northern and southern portion of a region
; for blocking detection (detecting reversal of geopotential height; unit: latitude)
;
; DLON: the minimum zonal extent of a blocking region (unit: degrees longitude)
;
; NX should be an odd integer
; **************************************************************************

DLAT 				= 15.
; NYSIZE 			= DLAT/GRIDSIZE				; reserved, unused in this script

DLON				= 15.
NX					= tointeger(DLON/GRIDSIZE)

if (mod(NX,2).eq.0) then
	NXHALF 			= tointeger(NX/2)
	NXHALFi			= -NXHALF
	NXHALFf			= NXHALF-1
else
	NXHALF 			= tointeger((NX-1)/2)
	NXHALFi			= -NXHALF
	NXHALFf			= NXHALF
end if

; ===========================================================================
; For tracking blocking regions
; ===========================================================================
; According to Masato et al. (2013, Journal of Climate),
;
; (1) point 2: a maximum detected at day n is within a 27x36 box
; (in latitude–longitude), centered at the blocking center of day n
; 27/2 = 13.5 degree latitudes
; 36/2 = 18 degree longitudes
;
; (2) point 4: an event is defined to finish when there is no positive
; continuation maximum within a box 1.5 times greater
; in both latitude and longitude than the box used
; in point 2, centered on the position of the onset
; maximum.
; 27*1.5/2 = 20 degree latitudes
; 36*1.5/2 = 27 degree longitudes


DLONCMAX			= 20.
DLATCMAX			= 12.5

DLONC0MAX			= 27.5
DLATC0MAX			= 20.

BLOCKMIN			= 5		; persistence criteria


; **************************************************************************
; pi constant

PI					= get_pi(1)


; ===========================================================================
; For outputting the profile of blocking region
; ===========================================================================

; TTTT --> reference time
TIMEREF				= 0

; RRRR --> blocking region
REGIONNUMBER		= 1

; ===================================================================

load "a1_draw_graph_resources.ncl"
load "step1_detect_blocking_grids.ncl"
load "step3_track_blocking_regions.ncl"
load "step4_count_blocking_frequency.ncl"
load "step5_group_blocking_event.ncl"
load "step6_cal_duration.ncl"

procedure cal_name(DATANAME:string)
begin


	DIRIN				        = "./data/"
	DIROUT				= "./blocking_2D_Scherrer/"	+ DATANAME + "/"
	DIRGRAPHOUT	        = "./blocking_2D_Scherrer/" + DATANAME + "/graph/"

	DIRBRINFO			= DIROUT + "region_info/"

	;
	system("mkdir -p " + DIROUT)
	system("mkdir -p " + DIRBRINFO)
	system("mkdir -p " + DIRGRAPHOUT)


	; Latitude and longitude profiles

	; **************************************************************************
	; Blocking profile (time, position, intensity and size)

	FBLOCKREGION		= DIROUT + "blocking_region_" + DATANAME + ".txt"

	TITLE 				= "0_region 1_file_no 2_time_position_in_file 3_reference_time 4_YYYYMMDD " + \
						  "5_year 6_month 7_day 8_lon_west 9_lon_east 10_lat_south 11_lat_north " + \
						  "12_Area 13_Z_max 14_lon_center 15_lat_center"

	; WWWW -> Write blocking profile

	system("echo " + TITLE + " > " + FBLOCKREGION)



	; DLONC0MAX			= 40.
	; DLATC0MAX			= 22.5

	print("Checking...1")
	FBLOCKREVENT		= DIROUT + "blocking_region_with_event_number_" + DATANAME + ".txt"

	print("Checking...2")

	; ===========================================================================
	; For filtering blocking regions
	; ===========================================================================

	FBLOCKEVENTNC		= DIROUT + "blocking_event_" + DATANAME + "_" + BLOCKMIN + "days.nc"

	; ===========================================================================
	; For grouping blocking events
	; ===========================================================================

	FBLOCKEVENT 		= DIROUT + "blocking_event_" + DATANAME + ".txt"

	; ===========================================================================
	; For blocking regions with duration
	; ===========================================================================

	FBLOCKEVENTD 		= DIROUT + "blocking_region_with_event_number_duration_" + DATANAME + ".txt"

	; ===========================================================================
	; For blocking regions with duration
	; ===========================================================================

	FILEIN		= systemfunc("ls " + DIRIN + "*.nc")
	NFIL		= dimsizes(FILEIN)

	NSTART 	= 0
	NEND	 	= NFIL-1
	NARR 		= ispan(NSTART,NEND,1)
	NSIZE		= dimsizes(NARR)

	; -------------------------------------------------------------
	; Steps 1-2: Detect blocking grids and locate blocking regions
	; Step 2 is called inside the script of step 1

	do NI = NSTART, NEND
		print(DATANAME + ": " + NI + "/" + NEND)

		f	 			= addfile(FILEIN(NI),"r")
		fRegionName 	= DIROUT + "blocking_region_" + NI + ".nc"

		; blocking regions are located inside this procedure
		detect_blocking_grids(NI,f,fRegionName,DIRGRAPHOUT,DIRBRINFO,FBLOCKREGION)

	end do

	; ; -------------------------------------------------------------
	; Step 3：Track blocking regions

	eventNumi	= 1 ; Number of the first event

	fGridName 	= DIROUT + "blocking_region_" + NARR + ".nc"

	track_blocking_regions(NSTART,fGridName,eventNumi,FBLOCKREGION,FBLOCKEVENT,FBLOCKREVENT)

	; -------------------------------------------------------------
	; Step 4: Filter blocking regions without persistence

	filter_blocking_events(fGridName,FBLOCKREVENT,FBLOCKEVENTNC)

	; -------------------------------------------------------------
	; Step 5: Group blocking events

	group_blocking_events(fGridName,FBLOCKREVENT,FBLOCKEVENT)

	; -------------------------------------------------------------
	; Step 6: Duraton of blocking events

	mergeDuration(DATANAME,FBLOCKREVENT,FBLOCKEVENTD)

end

begin


	DATAALLNAME			= (/"blocking","AlB50_B99","AlF50_F99","OI050_I99","OT050_T99","TroAl_Bas"/)
	NDATA				= dimsizes(DATAALLNAME)

	; do n = 0, NDATA-1
	do n = 0, 0
		cal_name(DATAALLNAME(n))
	end do

end
