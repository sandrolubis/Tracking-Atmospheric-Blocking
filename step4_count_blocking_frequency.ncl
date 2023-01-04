; Title OF FBLOCKREVENT
; "event 0_region 1_file_no 2_time_position_in_file 3_reference_time 4_YYYYMMDD " + \
; "5_year 6_month 7_day 8_lon_west 9_lon_east 10_lat_south 11_lat_north " + \
; "12_Area 13_Z_max 14_lon_center 15_lat_center"          
	
procedure filter_blocking_events(fGRIDNAME:string,FBLOCKREVENT:string,FBLOCKEVENTNC:string)
begin

	fBlockInfo		= readAsciiTable(FBLOCKREVENT,17,"float",(/1,0/))
	fBlock 			= addfiles(fGRIDNAME,"r")

	event 			= tointeger(fBlockInfo(:,0))
	eventMin		= min(event)
	eventMax 		= max(event)
	eventArr		= ispan(eventMin,eventMax,1)
	nEvent			= dimsizes(eventArr)

	region 			= fBlockInfo(:,1)
	timeRef			= tointeger(fBlockInfo(:,4))

	BR 				= fBlock[:]->blocking_region
	
	year			= fBlock[:]->year
	month			= fBlock[:]->month
	day				= fBlock[:]->day
	yearW 			= where(month.le.2,year-1,year)

	timeB 			= fBlock[:]->time
	timeIndex		= fBlock[:]->time_index
	timeOrder		= fBlock[:]->time_order

	; ==================================================================

	do ne = 0, nEvent-1
		eventInd 	:= ind(event.eq.eventArr(ne))
		
		if (.not. any(ismissing(eventInd))) then
			eventTime 	:= timeRef(eventInd)
			eventR 		:= region(eventInd) 
			
			nDay 		= max(eventTime)-min(eventTime)+1
			
			print(eventArr(ne) + " " + nDay)
			
			if (nDay.lt.BLOCKMIN) then
				nRegion	= dimsizes(eventTime)
				do nR = 0, nRegion-1
					BR(eventTime(nR),:,:) = where(BR(eventTime(nR),:,:).eq.eventR(nR),(/0/),(/BR(eventTime(nR),:,:)/))
				end do
			end if
			
			delete([/eventTime,eventR/])
			
		end if
			
		delete(eventInd)

	end do

	; ==================================================================

	BR				= where(BR.lt.0,(/0/),(/BR/))
	BRBinary		= BR
	BRBinary		= where(BR.le.0,(/0/),(/1/))
	
	dimNames 		= getvardims(BR)
	dimSizes 		= dimsizes(BR)
	dimUnlim 		= new(dimsizes(dimSizes),logical)
	dimUnlim 		= False

	system("/bin/rm -f " + FBLOCKEVENTNC)

	fOut			= addfile(FBLOCKEVENTNC,"c")

	filedimdef(fOut,dimNames,dimSizes,dimUnlim)

	filevardef(fOut,"time",typeof(timeB),getvardims(timeB))
	filevardef(fOut,"time_order",typeof(timeOrder),getvardims(timeOrder))
	filevardef(fOut,"time_index",typeof(timeIndex),getvardims(timeIndex))

	filevardef(fOut,"year",typeof(year),getvardims(timeB))
	filevardef(fOut,"month",typeof(month),getvardims(timeB))
	filevardef(fOut,"day",typeof(day),getvardims(timeB))

	filevardef(fOut,"lat",typeof(fBlock[0]->lat),getvardims(fBlock[0]->lat))
	filevardef(fOut,"lon",typeof(fBlock[0]->lon),getvardims(fBlock[0]->lon))

	filevardef(fOut,"blocking_count",typeof(BRBinary),dimNames)
	filevardef(fOut,"blocking_region",typeof(BR),dimNames)

	filevarattdef(fOut,"time",timeB)
	filevarattdef(fOut,"lat",fBlock[0]->lat)
	filevarattdef(fOut,"lon",fBlock[0]->lon)
	filevarattdef(fOut,"blocking_count",BRBinary)
	filevarattdef(fOut,"blocking_region",BR)

	fOut->time 				= (/timeB/)
	fOut->time_order 		= (/timeOrder/)
	fOut->time_index 		= (/timeIndex/)

	fOut->year 				= (/year/)
	fOut->month 			= (/month/)
	fOut->day 				= (/day/)

	fOut->lat 				= (/fBlock[0]->lat/)
	fOut->lon 				= (/fBlock[0]->lon/)

	fOut->blocking_count 	= (/BRBinary/)
	fOut->blocking_region 	= (/BR/)

end