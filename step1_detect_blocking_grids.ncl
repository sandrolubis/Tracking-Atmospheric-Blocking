load "./step2_locate_blocking_regions.ncl"
procedure detect_blocking_grids(numFil:integer,fil:file,filOUTNAME:string,DIRGRAPHOUT:string,DIRBRINFO:string,FBLOCKREGION:string)
begin

	; Coordinate variable: time, latitude and longitude
	print("1")

	time				= fil->$TIMENAME$ ; YYYYMMDD.5
	time 				= (/time-0.5/)
	time&time 			= time

	nTime 				= dimsizes(time)

	year				= tointeger(time/10000)
	month				= tointeger((time-year*10000)/100)
	day			        = tointeger(time-year*10000-month*100)
	YYYYMMDD		 = tointeger(time)

	; --------------------------------------------------------------------

	timeIndexOut		= ispan(0,nTime-1,1)
	timeIndexOut!0		= "time"
	timeIndexOut&time	= timeIndexOut

	timeOut				= ispan(TIMEREF,TIMEREF+nTime-1,1)
	timeOut!0			= "time"
	timeOut&time		= timeOut

	; --------------------------------------------------------------------
	latAll 				= fil->$LATNAME$
	latC 				= fil->$LATNAME$({LAT1:LAT2})

	; --------------------------------------------------------------------
	; latitude pairs to define reversal of geopotential height
	print("2")

	latN 				= latC
	latN 				= (/latC+DLAT/)
	latN&lat			= latN

	latS 				= latC
	latS 				= (/latS-DLAT/)
	latS&lat			= latS

	; --------------------------------------------------------------------
	; reference latitude to draw the contours using get_isolines
	print("3")

	latRefN 			= fil->$LATNAME$({LATREF1:LATREF2})
	latRefC 			= latRefN
	latRefC 			= (/latRefN-DLAT/)

	; --------------------------------------------------------------------
	lon	 				= fil->$LONNAME$

	nTime 				= dimsizes(time)
	nLatAll				= dimsizes(latAll)
	nLatC 				= dimsizes(latC)
	nLon	 			= dimsizes(lon)


	; -------------------------------------------------------------------
	; calcute the area of each grid point
	; a blocking high has to be at least 10**6 km**2

; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; ... VERY IMPORTANT!!!!!!!!!!!!!!!!!!!!!!!!
; ***** MUST be in clockwise direction *****
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	print("4")

	area2DAll			= new((/nLatAll,nLon/),typeof(latAll))
	area2D				= new((/nLatC,nLon/),typeof(latC))
	area2D!0			= "lat"
	area2D!1			= "lon"
	area2D&lat 			= latC
	area2D&lon 			= lon
	area2D@units 		= "km**2"

	do n = 0, nLatC-1
		y 				= (/latC(n)-GRIDSIZE/2.,latC(n)+GRIDSIZE/2.,latC(n)+GRIDSIZE/2.,latC(n)-GRIDSIZE/2./)
		x 				= (/0.,0.,GRIDSIZE,GRIDSIZE/)
		area2D(n,:)		= (/area_poly_sphere(y,x,6371)/1E6/) ; return area of a polygon in km**2

		delete([/x,y/])
	end do
	print("5")

	; expand latC and lon to 2-D
	; for finding whether the regions are inside the closed isolines
	; for calculating the mass-averaged center

	latAll2D 			= conform_dims(dimsizes(area2DAll),latAll,0)
	latC2D 				= conform_dims(dimsizes(area2D),latC,0)
	lon2D 				= conform_dims(dimsizes(area2D),lon,1)

	; -------------------------------------------------------------------
	; Call zonal index equations

	if (ISLEVEL) then
		if (getfilevartypes(fil,ZNAME).eq."short") then
			hgtA			= short2flt(fil->$ZNAME$(:,{LEVZ},:,:))
		else
			hgtA 			= fil->$ZNAME$(:,{LEVZ},:,:)
		end if
	else

		if (getfilevartypes(fil,ZNAME).eq."short") then
			hgtA			= short2flt(fil->$ZNAME$)
			printVarSummary(hgtA)
		else
			hgtA 			= fil->$ZNAME$
		end if
	end if

	hgtZA					= dim_rmvmean_Wrap(hgtA) ; remove zonally average

	; -------------------------------------------------------------------

	hgtN					= hgtA(:,{latN},:)
	hgtZAC 					= hgtZA(:,{latC},:)
	hgtC 					= hgtA(:,{latC},:)
	hgtS 					= hgtA(:,{latS},:)

	; GHGN (zonal index equation in the northern portion of a blocking region)
	zonalIndexN				= (/(hgtN-hgtC)/DLAT/)

	; GHGS (zonal index equation in the southern portion of a blocking region)
	zonalIndexS				= (/(hgtC-hgtS)/DLAT/)

	copy_VarCoords(hgtC,zonalIndexN)
	copy_VarCoords(hgtC,zonalIndexS)

	; -------------------------------------------------------------------
	; In step2, contours will be drawn based on zonalIndexRef,
	; where the regions with positive values of zonalIndexRef (> 0)
	; will be further examined if they are a potential blocking region
	;
	; Here, we set zonalIndexRef to be positive when it fulfil the
	; following three criteria; otherwise, it is set as -1
	; (1) Latitude between 40 and LATREF2C degrees north
	; (2) Reversal meridional geopotential height gradient
	; (3) Positive eddy geopotential height anomaly (ridge)

	hgtZAN					= hgtZA(:,{latRefN},:)
	hgtRefN					= hgtA(:,{latRefN},:)
	hgtRefC					= hgtA(:,{latRefC},:)

	latN3D 					= conform_dims(dimsizes(hgtRefN),latAll({latRefN}),1)

	zonalIndexRef								= (/(hgtRefN-hgtRefC)/DLAT/) ; reversal of the meridional gradient
	copy_VarCoords(hgtRefN,zonalIndexRef)

	zonalIndexRefN								= zonalIndexRef
	zonalIndexRefN(:,{LATREF1C:LATREF2C},:) 	= (/zonalIndexRef(:,{LATREF1N:LATREF2N},:)/)
	zonalIndexRefN(:,{LATREF2C:90},:) 			= (/0/)

	zonalIndexRef								= (/where(zonalIndexRefN.lt.-10 .and. hgtZAN.gt.0,zonalIndexRef,-1)/)
	zonalIndexRef								= (/where(latN3D.ge.45,zonalIndexRef,-1)/)

	delete([/hgtZA,hgtZAN,zonalIndexRefN/])

	printVarSummary(zonalIndexRef)

	; -------------------------------------------------------------------
	; blockingGrid2D will also be used to detect the blocking region in step2
	; 1-> blocking grid (reversal meriidonal geopotential gradient
	; .................. and ridge)
	; 0-> non-blocking grid

	blockGrid2D 		= new(dimsizes(zonalIndexN),integer)
	blockGrid2D 		= where(zonalIndexN.lt.-10 .and. zonalIndexS.gt.0 .and. hgtZAC.gt.0, (/1/),(/0/))
	copy_VarCoords(zonalIndexN,blockGrid2D)

	blockGrid2D			= (/blockGrid2D*-1/)

	; *******************************************************************
	; *******************************************************************
	; Call function to find the grid with reversal of geopotential height
	; *******************************************************************
	; *******************************************************************

	do nt = 0, nTime-1
	; do nt = 0, 30

		timeBStr 			= timeIndexOut(nt) + " " + timeOut(nt) + " " + YYYYMMDD(nt) + " " + \
							  year(nt) + " " + month(nt) + " " +  day(nt)

		system("echo Date = " +YYYYMMDD(nt))

		search_blocking_region(numFil,latAll2D,latC2D,lon2D,area2D,hgtA(nt,:,:),hgtC(nt,:,:),zonalIndexRef(nt,:,:), \
							   blockGrid2D(nt,:,:),sprinti("%i",YYYYMMDD(nt)),timeBStr,DIRGRAPHOUT,DIRBRINFO,FBLOCKREGION)

		print("Hi")
	end do

	print("Output file")

	; *******************************************************************
	; *******************************************************************
	;
	; Output blocking regions to a NetCDF file
	; --- for counting blocking frequency

	dimNames 		= getvardims(blockGrid2D)
	dimSizes 		= dimsizes(blockGrid2D)
	dimUnlim 		= new(dimsizes(dimSizes),logical)
	dimUnlim 		= False

	system("/bin/rm -f " + filOUTNAME)

	fOut			= addfile(filOUTNAME,"c")

	filedimdef(fOut,dimNames,dimSizes,dimUnlim)

	filevardef(fOut,"time",typeof(time),getvardims(time))
	filevardef(fOut,"time_index",typeof(timeIndexOut),getvardims(timeIndexOut))
	filevardef(fOut,"time_order",typeof(timeOut),getvardims(time))

	filevardef(fOut,"year",typeof(year),getvardims(time))
	filevardef(fOut,"month",typeof(month),getvardims(time))
	filevardef(fOut,"day",typeof(day),getvardims(time))

	filevardef(fOut,"lat",typeof(latC),getvardims(latC))
	filevardef(fOut,"lon",typeof(lon),getvardims(lon))

	filevardef(fOut,"blocking_region",typeof(blockGrid2D),dimNames)

	filevarattdef(fOut,"time",time)
	filevarattdef(fOut,"lat",latC)
	filevarattdef(fOut,"lon",lon)
	filevarattdef(fOut,"blocking_region",blockGrid2D)

	fOut->time 				= (/time/)
	fOut->time_index 		= (/timeIndexOut/)
	fOut->time_order 		= (/timeOut/)

	fOut->year 				= (/year/)
	fOut->month 			= (/month/)
	fOut->day 				= (/day/)

	fOut->lat 				= (/latC/)
	fOut->lon 				= (/lon/)

	fOut->blocking_region 	= (/blockGrid2D/)


	TIMEREF 				= TIMEREF+nTime

end
