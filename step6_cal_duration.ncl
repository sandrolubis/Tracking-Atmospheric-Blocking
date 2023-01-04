procedure mergeDuration(DATANAME:string,FBLOCKREVENT:string,FBLOCKEVENTD:string)
begin

	fBlockStr		= asciiread(FBLOCKREVENT,-1,"string")
	fBlockInfo		= readAsciiTable(FBLOCKREVENT,17,"float",(/1,0/))
	
	event 			= tointeger(fBlockInfo(:,0))
	eventMin		= min(event)
	eventMax 		= max(event)
	eventArr		= ispan(eventMin,eventMax,1)
	nEvent			= dimsizes(eventArr)
	
	time 			= tointeger(fBlockInfo(:,4))
	nRegion 		= dimsizes(time)

	blockDay		= new(nRegion,integer)
	blockLife		= new(nRegion,integer)
	
	do ne = 0, nEvent-1
	
		print(DATANAME + "  " + (/ne+1/) + "/" + nEvent)
	
		eventInd 	:= ind(event.eq.eventArr(ne))
		
		if (.not. any(ismissing(eventInd))) then
			eventTime 	:= time(eventInd)
			nDay 		= max(eventTime)-min(eventTime)+1
		
			blockDay(eventInd)  = eventTime-eventTime(0) 
			blockLife(eventInd) = nDay
			
			delete(eventTime)
			
		end if
			
	end do
	
	fBlockStr(0)	= "Day Duration " + fBlockStr(0)
	fBlockStr(1:)	= blockDay + " " + blockLife + " " + fBlockStr(1:)
	
	asciiwrite(FBLOCKEVENTD,fBlockStr)
	
	
end