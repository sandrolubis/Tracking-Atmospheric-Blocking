; **************************************************************************
; **************************************************************************
; Step 3 in blocking detecting algorithm
; Tracking blocking regions
; **************************************************************************
; **************************************************************************
; Title OF FBLOCKREGION (input text file)
; 16 items for each blocking region
; that have been written on the same row in the text file
;
; "0_region 1_file_no 2_time_position_in_file 3_reference_time 4_YYYYMMDD " + \
; "5_year 6_month 7_day 8_lon_west 9_lon_east 10_lat_south 11_lat_north " + \
; "12_Area 13_Z_max 14_lon_center 15_lat_center"

procedure track_blocking_regions(numSTART:numeric,fGRIDNAME:string,EVENTNUMBER:integer,FBLOCKREGION:string,FBLOCKEVENT:string,FBLOCKREVENT:string)
begin

	; read the text file keeping blocking regions
	; fIn: read as float
	; fInINT: read as integer
	; fInStr: read as string

	fIn					  = readAsciiTable(FBLOCKREGION,16,"float",(/1,0/))
	fInINT				= readAsciiTable(FBLOCKREGION,16,"integer",(/1,0/))
	fInStr				= asciiread(FBLOCKREGION,-1,"string")
	;
	; print(fIn)
	; print(fInINT)
	; print(fInStr)
	; =====================================================================
	; read quantities from the text files

	time 				= fInINT(:,3)
	timeMin				= min(time)
	timeMax				= max(time)

	timeArr 			= ispan(timeMin,timeMax,1)
	nTime 				= dimsizes(timeArr)

	region 				= fInINT(:,0)
	file_number			= fInINT(:,1)
	time_location		= tointeger(fIn(:,2))

	year 				= fInINT(:,5)
	month 				= fInINT(:,6)
	day 				= fInINT(:,7)

	latCIn 				= fIn(:,15)
	lonCIn 				= fIn(:,14)

	; =====================================================================

	nAll 				= dimsizes(region)
	eventNum			= new(nAll,integer)

	fOutStr				= fInStr
	fOutStr(0)			= "event " + fOutStr(0)

	; ======================================================================
	; execute the loop for each of the dates from timeMin to timeMax

	do nt = 0, nTime-1
	; do nt = 0, 0

		print((/nt+1/) + "/" + nTime)

		timeTInd		= ind(time.eq.timeArr(nt))

		; TTTT1
		; Some calendar days do not have blocking regions
		; only execute the if-statement when blocking region(s) exist
		; on a specific date


; begin of TTTT1a
		if (.not. any(ismissing(timeTInd))) then
			; TTTT1a

			strDate = sprinti("%04i",year(timeTInd(0)))+sprinti("%02i",month(timeTInd(0)))+sprinti("%02i",day(timeTInd(0)))
			print("Track blocking regions. Date: "+ strDate + ", event = " + EVENTNUMBER)

			fileT			= file_number(timeTInd)
			timeT			= time_location(timeTInd)
			regionT			= region(timeTInd)

			fBlockGrid 		= addfile(fGRIDNAME(fileT(0)-numSTART),"r")
			BR				= fBlockGrid->blocking_region(timeT(0),:,:)
			nRegionT 		= dimsizes(timeTInd)

			printVarSummary(BR)
			latCT			= latCIn(timeTInd)
			lonCT 			= lonCIn(timeTInd)

			; TTTT2
			; Conditional statement
			;
			; a blocking region exists in the previous calendar day
			; => isvar("eventOld") = True
			; a variable eventOld is created at the end of each calendar day
			;
			; no blocking regions exist in the previous calendar day
			; => isvar("eventOld") = False

; begin of TTTT2
			if (.not. isvar("eventOld")) then
				print("No old events = "+strDate)

				eventOld			= ispan(EVENTNUMBER,EVENTNUMBER+nRegionT-1,1)

				eventLife			= eventOld
				eventLife			= 1

				eventStop			= eventOld
				eventStop			= 0

				regionOld			= regionT

				latCOld 			= latCT
				lonCOld 			= lonCT

				latC0Old 			= latCT
				lonC0Old 			= lonCT

				fileOld 			= fileT
				timeOld 			= timeT

				eventNum(timeTInd)	= (/eventOld/)
				EVENTNUMBER			= EVENTNUMBER+nRegionT

			else

				nOld 				= dimsizes(lonCOld)

				print(nOld + " old event(s) = "+strDate)

				; latCT2D and lonCT2D: for assigning the latitude and longitude center
				latCT2D				= new((/nRegionT,nOld/),float)
				lonCT2D				= new((/nRegionT,nOld/),float)

				latCT2D				= conform_dims(dimsizes(latCT2D),latCT,0)
				lonCT2D				= conform_dims(dimsizes(lonCT2D),lonCT,0)

				eventT				:= new(nRegionT,integer)

				findOld				:= new(nRegionT,logical)
				findOld 			= False

				findDist			:= new(nRegionT,float)
				findDist			= 0.

				matchOld 			:= new((/nRegionT,nOld/),integer)
				matchOld			= 0

				matchRegion			:= new(nOld,integer)

				; tracking all blocking regions in the calendar day (nt)
				do nr = 0, nRegionT-1
; begin of TTTT3
					match 			= new(nOld,logical)
					match 			= False
					nMatch 			= 0

					dBlock			:= new(nOld,float)
					dLat			:= new(nOld,float)
					dLon			:= new(nOld,float)

					dLat0			:= new(nOld,float)
					dLon0			:= new(nOld,float)

					; print("first region = " + latC0Old + " " + lonC0Old)
					; print("Old region = " + latCOld + " " + lonCOld)
					; print("new region = " + latCT2D + " " + lonCT2D)

					; tracking the blocking regions on nt with those on nt-1

					do m = 0, nOld-1
; begin of TTTT4
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; Need to check (2019 Apr 7)
; 2016 Jan 21 to 22 is not continous

						; print(""+m + "/" + nOld)
						; print(latCT(nr) + " " + lonCT(nr))
						; print(latCOld(nr) + " " + lonCOld(nr))
						; print(latC0Old(nr) + " " + lonC0Old(nr))

						dBlock(m)	= gc_latlon(latCT(nr),lonCT(nr),latCOld(m),lonCOld(m),1,2)
						dLat(m)		= gc_latlon(latCT(nr),0,latCOld(m),0,1,2)
						dLon(m)		= gc_latlon(0,lonCT(nr),0,lonCOld(m),1,2)

						dLat0(m)	= gc_latlon(latCT(nr),0,latC0Old(m),0,1,2)
						dLon0(m)	= gc_latlon(0,lonCT(nr),0,lonC0Old(m),1,2)

						; print("dLat = " + dLat(m) + ", dLon = " + dLon(m))
						; print("dLat_max = " + DLATCMAX + ", dLon_max = " + DLONCMAX)

						if (dLat(m).le.DLATCMAX .and. dLon(m).le.DLONCMAX) then
							; printVarSummary(fileT)
							; print(fileT)
							; print(""+m)
							; print(fileT(m) + " " + numSTART)

							fBlockGridOld	= addfile(fGRIDNAME(fileOld(m)-numSTART),"r")
							BROld			= fBlockGridOld->blocking_region(timeOld(m),:,:)
							delete(fBlockGridOld)

							BRCmp1	= where(BROld.eq.regionOld(m),(/1/),(/0/))
							BRCmp2	= where(BR.eq.regionT(nr),(/1/),(/0/))
							BRCmp 	= BRCmp1
							BRCmp 	= (/BRCmp1+BRCmp2/)
							; print("BR min max")
							; printMinMax(BRCmp1,True)
							; printMinMax(BRCmp2,True)

							if (eventLife(m).gt.1) then

								print("dLat0 = " + dLat0(m) + ", dLon0 = " + dLon0(m))
								print(dLat0(m) + " vs. " + DLATC0MAX)
								print(dLon0(m) + " vs. " + DLONC0MAX)

								if (dLat0(m).le.DLATC0MAX .and. dLon0(m).le.DLONC0MAX) then
									match(m) = True
									nMatch	 = nMatch+1
								end if
							else
								match(m) = True
								nMatch	 = nMatch+1
							end if

							delete([/BRCmp1,BRCmp2,BRCmp,BROld/])
						end if
; end of TTTT4
					end do


					; conditional statement for the blocking regions to be continous
					; from the calendar day (nt-1) to the calendar day (nt)

					if (nMatch.ge.1) then

						; print("nMatch = " + nMatch)

						findOld(nr) = True

						; only one old event matches
						if (nMatch.eq.1) then
							matchInd 					= ind(match.eq.True)
							eventT(nr) 					= eventOld(matchInd)
							findDist(nr)				= dBlock(matchInd)
							matchOld(nr,matchInd) 		= 1

						; more than one old events match
						else
							matchInd  						= ind(match.eq.True)
							minInd 							= minind(dBlock(matchInd))

							eventT(nr) 						= eventOld(matchInd(minInd))
							findDist(nr) 					= dBlock(matchInd(minInd))
							matchOld(nr,matchInd(minInd)) 	= 1

							delete(minInd)
						end if

						delete(matchInd)

					end if

					delete([/match,dBlock,dLat,dLon,dLat0,dLon0/])

; end of TTTT3
				end do


; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; 2019 Apr 9
; Check this part
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;				Old event persists
; 				Old event does not persist
; 				New event

;				findOld: nRegion
;				matchOld1D: nOld
; 				nRegion =/= nOld

				; a region on day nt matches with at least two regions on day nt-1

				matchOld1D					= dim_sum_n(matchOld,0) ; dimension: nOld

				matchMulti 					= ind(matchOld1D.gt.1)

				if (.not. any(ismissing(matchMulti))) then
					nMulti					= dimsizes(matchMulti)
					do nM = 0, nMulti-1
						eventMInd 			= ind(eventT.eq.eventOld(matchMulti(nM)))
						distM 				= findDist(eventMInd)

						distMInd			= ispan(0,dimsizes(distM)-1,1)
						excludeInd 			= ind(distMInd.ne.minind(distM))
						; print("Exclude = " + excludeInd)

						findOld(eventMInd(excludeInd)) = False

						do nMO = 0, nOld-1
							matchOld(eventMInd(excludeInd),nMO) = 0
						end do

						delete([/eventMInd,distM,distMInd,excludeInd/])
					end do
				end if


				; ===============================================================
				; New events

				; eventNewInd					= ind(findOld.eq.False)

				; eventNewInd					= ind(matchOld1D.eq.0 .and. (matchOld1D.ne.0 .and. eventStop.ne.0))
				; eventContInd				= ind(matchOld1D.eq.1 .or. (matchOld1D.eq.0 .and. eventStop.eq.0))

				eventNewInd					= ind(findOld.eq.False)
				eventContInd				= ind(matchOld1D.eq.1 .or. (matchOld1D.eq.0 .and. eventStop.eq.0))

				if (.not. any(ismissing(eventNewInd))) then

					nNew 					= dimsizes(eventNewInd)

					; print("")
					; print("Keep " + nNew + "new events")
					; print("")

					eventT(eventNewInd)		= ispan(EVENTNUMBER,EVENTNUMBER+nNew-1,1)
					eventNew				= ispan(EVENTNUMBER,EVENTNUMBER+nNew-1,1)

					EVENTNUMBER				= EVENTNUMBER+nNew

					; ...........................................................

					eventNewLife			= eventNew
					eventNewLife			= 1

					eventNewStop			= eventNew
					eventNewStop			= 0

					regionNew				= regionT(eventNewInd)

					latCNew 				= latCT(eventNewInd)
					lonCNew	 				= lonCT(eventNewInd)

					latC0New	 			= latCT(eventNewInd)
					lonC0New 				= lonCT(eventNewInd)

					yrNew 					= fileT(eventNewInd)
					dayNew 					= timeT(eventNewInd)

					if (all(ismissing(eventContInd))) then

						; print(nNew + " new events.")

						delete([/eventOld,eventLife,eventStop,regionOld,latCOld,lonCOld,\
								 latC0Old,lonC0Old,fileOld,timeOld/])

						eventOld			= eventNew
						eventLife			= eventNewLife
						eventStop			= eventNewStop

						regionOld			= regionNew
						latCOld				= latCNew
						latC0Old			= latC0New
						lonCOld				= lonCNew
						lonC0Old			= lonC0New

						fileOld				= yrNew
						timeOld				= dayNew

						delete([/eventNew,eventNewLife,eventNewStop,regionNew, \
							   latCNew,lonCNew,latC0New,lonC0New,yrNew,dayNew/])

					end if
				end if

				; ===============================================================
				; Continuing

				; print("")
				; print("Keep old events")
				; print("")

				; printVarSummary(latCT)
				; printVarSummary(lonCT)

				; printVarSummary(latC0Old)
				; printVarSummary(lonC0Old)

				; print(eventContInd)
				; print(matchOld)


				if (.not. any(ismissing(eventContInd))) then

					eventOldTmp			= eventOld(eventContInd)
					eventLifeTmp		= eventLife(eventContInd)+1
					eventStopTmp		= eventStop(eventContInd)

					regionOldTmp		= regionOld(eventContInd)
					latC0OldTmp			= latC0Old(eventContInd)
					lonC0OldTmp			= lonC0Old(eventContInd)

					nCont 				= dimsizes(eventContInd)

					latCOldTmp			= new(nCont,typeof(latCT2D))
					lonCOldTmp			= new(nCont,typeof(lonCT2D))

					do nc = 0, nCont-1

						matchOldnc 		:= matchOld(:,eventContInd(nc))

						if (max(matchOldnc).eq.1) then

							ncInd 			:= min(ind(matchOldnc.eq.1)) ; should have only one value
							print(ncInd)
							latCOldTmp(nc)	= latCT2D(ncInd,eventContInd(nc))
							lonCOldTmp(nc)	= lonCT2D(ncInd,eventContInd(nc))
							delete(ncInd)

						else

							latCOldTmp(nc) 	= latCOld(eventContInd(nc))
							lonCOldTmp(nc) 	= lonCOld(eventContInd(nc))

						end if

					end do
					fileOldTmp			= fileOld(eventContInd)
					timeOldTmp			= timeOld(eventContInd)

					; if no region matches, add one to eventStop
					matchCont 			= matchOld1D(eventContInd)
					eventStopTmp		= where(matchCont.eq.0,1,0)

					if (all(ismissing(eventNewInd))) then

						print(dimsizes(eventContInd) + " old events.")

						delete([/eventOld,eventLife,eventStop,regionOld,latCOld,lonCOld,\
								 latC0Old,lonC0Old,fileOld,timeOld/])

						eventOld			= eventOldTmp
						eventLife			= eventLifeTmp
						eventStop			= eventStopTmp

						regionOld			= regionOldTmp
						latCOld				= latCOldTmp
						latC0Old			= latC0OldTmp
						lonCOld				= lonCOldTmp
						lonC0Old			= lonC0OldTmp

						fileOld				= fileOldTmp
						timeOld				= timeOldTmp

						delete([/eventOldTmp,eventLifeTmp,eventStopTmp,regionOldTmp, \
							   latCOldTmp,latC0OldTmp,lonCOldTmp,lonC0OldTmp,fileOldTmp,timeOldTmp/])

					end if
					delete(matchCont)
				end if

				if ((.not. any(ismissing(eventNewInd))).and.(.not. any(ismissing(eventContInd)))) then

					print(dimsizes(eventContInd) + " old events and " + nNew + " new events.")

					delete([/eventOld,eventLife,eventStop,regionOld,latCOld,lonCOld,\
							 latC0Old,lonC0Old,fileOld,timeOld/])

					eventOld			:= array_append_record(eventOldTmp,eventNew,0)
					eventLife			:= array_append_record(eventLifeTmp,eventNewLife,0)
					eventStop			:= array_append_record(eventStopTmp,eventNewStop,0)

					regionOld			:= array_append_record(regionOldTmp,regionNew,0)
					latCOld				:= array_append_record(latCOldTmp,latCNew,0)
					latC0Old			:= array_append_record(latC0OldTmp,latC0New,0)
					lonCOld				:= array_append_record(lonCOldTmp,lonCNew,0)
					lonC0Old			:= array_append_record(lonC0OldTmp,lonC0New,0)

					fileOld				:= array_append_record(fileOldTmp,yrNew,0)
					timeOld				:= array_append_record(timeOldTmp,dayNew,0)

					delete([/eventOldTmp,eventLifeTmp,eventStopTmp,regionOldTmp, \
						   latCOldTmp,latC0OldTmp,lonCOldTmp,lonC0OldTmp,fileOldTmp,timeOldTmp/])


					delete([/eventNew,eventNewLife,eventNewStop,regionNew, \
						   latCNew,lonCNew,latC0New,lonC0New,yrNew,dayNew/])

				end if

				; ================================================================

				eventNum(timeTInd)			= (/eventT/)

				delete([/matchOld,matchOld1D,findOld,findDist,matchMulti,eventNewInd,eventContInd,eventT/])
				delete([/latCT2D,lonCT2D/])
; end of TTTT2
			end if

			delete([/fileT,timeT,regionT,BR,latCT,lonCT/])

		else
			; TTTT1
			; no blocking regions on the calendar day

			if (isvar("eventOld")) then
				if (all(eventStop.gt.0))

					; print("No blocking. No old events remain.")

					delete([/eventOld,eventLife,eventStop,regionOld,latCOld,lonCOld,\
							 latC0Old,lonC0Old,fileOld,timeOld/])
				else

					; keep blocking events not persisting for the first day
					; as one non-blocking day is allowed
					; e.g. day+0 is blocking, day+1 is not blocked, day+2 is blocked
					; day+0 to day+2 are considered as blocked

					eventKeepInd		:= ind(eventStop.eq.0)

					; print("No blocking, " + dimsizes(eventKeepInd) + " event(s) keep.")

					eventOldTmp			:= eventOld(eventKeepInd)
					eventLifeTmp		:= eventLife(eventKeepInd)+1
					eventStopTmp		:= eventStop(eventKeepInd)+1

					regionOldTmp		:= regionOld(eventKeepInd)
					latCOldTmp			:= latCOld(eventKeepInd)
					latC0OldTmp			:= latC0Old(eventKeepInd)
					lonCOldTmp			:= lonCOld(eventKeepInd)
					lonC0OldTmp			:= lonC0Old(eventKeepInd)

					fileOldTmp 			:= fileOld(eventKeepInd)
					timeOldTmp			:= timeOld(eventKeepInd)

					delete([/eventOld,eventLife,eventStop,regionOld,latCOld,lonCOld, \
							 latC0Old,lonC0Old,fileOld,timeOld/])

					eventOld			:= eventOldTmp
					eventLife			:= eventLifeTmp
					eventStop			:= eventStopTmp

					regionOld			:= regionOldTmp
					latCOld				:= latCOldTmp
					latC0Old			:= latC0OldTmp
					lonCOld				:= lonCOldTmp
					lonC0Old			:= lonC0OldTmp

					fileOld				:= fileOldTmp
					timeOld				:= timeOldTmp

					delete([/eventKeepInd,eventOldTmp,eventLifeTmp,eventStopTmp,regionOldTmp, \
						   latCOldTmp,lonCOldTmp,latC0OldTmp,lonC0OldTmp,fileOldTmp,timeOldTmp/])

				end if
			end if
; end of TTTT1
		end if
		delete(timeTInd)
		print("                      ")
	end do

	fOutStr(1:) = eventNum + " " + fOutStr(1:)
	asciiwrite(FBLOCKREVENT,fOutStr)

end
