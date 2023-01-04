; Input title: FBLOCKREVENT
; "event 0_region 1_file_no 2_time_position_in_file 3_reference_time 4_YYYYMMDD " + \
; "5_year 6_month 7_day 8_lon_west 9_lon_east 10_lat_south 11_lat_north " + \
; "12_Area 13_Z_max 14_lon_center 15_lat_center"        

; Output title: FBLOCKEVENT
; "0_event 1_duration 2_begin_year 3_begin_month 4_begin_day 
;  5_end_year 6_end_month 7_end_day 
;  8_begin_lat_lon 9_begin_lon_center 10_begin_lat_center 
;  11_end_lat_lon 12_end_lon_center 13_end_lat_center     
				  
	
procedure group_blocking_events(fGRIDNAME:string,FBLOCKREVENT:string,FBLOCKEVENT:string)
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

	year 			= tointeger(fBlockInfo(:,6))
	month 			= tointeger(fBlockInfo(:,7))
	day				= tointeger(fBlockInfo(:,8))
		
	lonW			= fBlockInfo(:,9)
	lonE			= fBlockInfo(:,10)

	latS			= fBlockInfo(:,11)
	latN			= fBlockInfo(:,12)

	lonC			= fBlockInfo(:,15)
	latC			= fBlockInfo(:,16)

	
	; BR 				= fBlock[:]->blocking_region
	
	; year			= fBlock[:]->year
	; month			= fBlock[:]->month
	; day				= fBlock[:]->day
	; yearW 			= where(month.le.2,year-1,year)

	; timeB 			= fBlock[:]->time
	; timeIndex		= fBlock[:]->time_index
	; timeOrder		= fBlock[:]->time_order

	; ==================================================================

	strOut			= new(nEvent+1,string)
	strOut(0)		= "0_event 1_duration 2_begin_year 3_begin_month 4_begin_day  " + \
					  "5_end_year 6_end_month 7_end_day " + \
					  "8_begin_lon_lat 9_begin_lon_center 10_begin_lat_center " + \
					  "11_end_lon_lat 12_end_lon_center 13_end_lat_center"
	
	do ne = 0, nEvent-1
	
		print((/ne+1/) + "/" + nEvent)
		eventInd 	:= ind(event.eq.eventArr(ne))
		print(eventInd)
		
		if (.not. any(ismissing(eventInd))) then
			eventTime 	:= timeRef(eventInd)
			eventR 		:= region(eventInd) 
			
			nDay 		= max(eventTime)-min(eventTime)+1
			
			; -----------------------------------------------------------
			
			eventi 		= min(eventInd)
			eventf 		= max(eventInd)
			
			print(eventi + " " + eventf)
			
			str1 		= year(eventi) + " " + month(eventi) + " " + day(eventi) + " " + \
						  year(eventf) + " " + month(eventf) + " " + day(eventf) 
			
			str2 		= lonW(eventi) + "-" + lonE(eventi) + "E," + \
						  latS(eventi) + "-" + latN(eventi) + "N " + \
						  lonC(eventi) + " " + latC(eventi)
			
			str3 		= lonW(eventf) + "-" + lonE(eventf) + "E," + \
						  latS(eventf) + "-" + latN(eventf) + "N " + \
						  lonC(eventf) + " " + latC(eventf)
			
			; -----------------------------------------------------------
			
			strOut(ne+1)	= eventArr(ne) + " " + nDay + " " + str1 + " " + str2 + " " + str3
			
		end if
			
		delete(eventInd)

	end do

	asciiwrite(FBLOCKEVENT,strOut)
	
end