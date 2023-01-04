; numFil:  		the count in the file sequence in the input directory
;				Given that there are n Files, this value spans from 0 to n-1

; latTwoD:  	latitude of each grid point in the central blocking region: [lat]x[lon]
; latTwoD:  	longitude of each grid point in the central blocking region: [lat]x[lon]
; areaTwoD: 	area of each grid point in the central blocking region: [lat]x[lon]
; ZAll:     	daily geopotential height (global)
; ZDay:     	daily geopotential height in the central blocking region
; GHGSRef:  	daily geopotential height gradient

; blockGRID: 	a binary index representing the grid with a reversal of meridional geopotential height gradient
;				0: reversal of meridional geopotential height gradient
;				1: non-reversal of meridional geopotential height gradient

; timeSTROUT:	a string containing the time information, which is for outputting purpose


procedure search_blocking_region(numFil:numeric,latTwoDAll:numeric,latTwoD:numeric,lonTwoD:numeric,areaTwoD:numeric,ZAll:numeric,ZDay:numeric,GHGSRef:numeric, \
								 blockGRID:numeric,dateSTROUT:string,timeSTROUT:string,DIRGRAPHOUT:string,DIRBRINFO:string,FBLOCKREGION:string)
begin
	print(dateSTROUT)
	
	blockOrig1D 		= ndtooned(blockGRID)

	lonMin				= min(lonTwoD)
	lonMax				= max(lonTwoD)
	
	latOneD 			= ndtooned(latTwoD)
	lonOneD 			= ndtooned(lonTwoD)
	
	copy_VarCoords(ZAll,latTwoDAll)
	
	; ===================================================================
	; Draw isoline for locating potential 2-D blocking regions
	
	wksName				= DIRGRAPHOUT + "block_region_" + dateSTROUT
	
	wks  				= gsn_open_wks("ps","block_detect")
	plotB 				:= gsn_csm_contour(wks,GHGSRef,RESDETECT)
	
	isoline  			:= get_isolines(plotB,0)
	
	delete([/wks,plotB/])	
	system("/bin/rm -f block_detect")
	
	if (.not. any(ismissing(isoline))) then
		nLine				= isoline@segment_count
		
		latBegin			= new(nLine,float)
		latEnd				= new(nLine,float)
		latMax				= new(nLine,float)
		
		lonBegin			= new(nLine,float)
		lonEnd				= new(nLine,float)

		; Note that this method would split the region at 360E/0E into two regions
		; We have to merge the two regions 
		; -> see MMMM

		do nL = 0, nLine-1
		
			b				:= isoline@start_point(nL)
			e				:= b+isoline@n_points(nL)-1
			
			latL 			:= isoline(0,b:e)
			lonL 			:= isoline(1,b:e)
			nPoint 			= dimsizes(latL)
			
			; print(nL + " "+ latL +  "  " + lonL)
			latBegin(nL)	= latL(0)
			latEnd(nL)		= latL(nPoint-1)
			latMax(nL)		= max((/latL(0),latL(nPoint-1)/))
			
			lonBegin(nL)	= lonL(0)
			lonEnd(nL)		= lonL(nPoint-1)
			
			delete([/latL,lonL/])
			
		end do
		
		; print(isoline)
		; exit
		
		; **********************************************************************
		; GGGG 
		
		if (DRAWGRAPH)
			; PLOT GRAPH ONLY
			wks  				= gsn_open_wks("eps",wksName)
			gsn_define_colormap(wks,"amwg_blueyellowred")
			; plotZ 				:= gsn_csm_contour_map_ce(wks,GHGSRef,RESLINE)
			
			plotZ 				:= gsn_csm_contour_map_ce(wks,dim_rmvmean_Wrap(ZAll),RESFILL)
			plotCN				= gsn_csm_contour(wks,ZAll,RES2)
			plotCN2				= gsn_csm_contour(wks,GHGSRef,RESLINE2)
			overlay(plotZ,plotCN)
			overlay(plotZ,plotCN2)
		end if

		; **********************************************************************
								
		; MMMM: Merge regions across 360E/0E
		;
		; Look for a segment joining the same latitude as 360E at 0E
		lineCheck						= new(nLine,logical)
		lineCheck 						= False
		
		; GGGG: for adding marker to the graph
		plotMark						= new(nLine,graphic)
		cntMark							= 0
		
		; a blocking region at least has 15 degrees meridional extent
		regionExclude 					= ind(latMax.lt.0) 
		
		if (.not. any(ismissing(regionExclude))) then
			lineCheck(regionExclude)	= True
		end if

		do while (.not. all(lineCheck))
			lineInd 					= min(ind(.not. lineCheck)) ; minind does not work here, use min(ind(value)) instead
			lineCheck(lineInd) 			= True
			
			; print(timeSTROUT +  " region " + lineInd  + ": " + latBegin(lineInd) + "-" +latEnd(lineInd) + "N, " +  lonBegin(lineInd) + "-" + lonEnd(lineInd)+"E")
				
			; a region that is not split has a closed contour (the first and last grid point is the same)
				
			if (latBegin(lineInd).eq.latEnd(lineInd) .and. lonBegin(lineInd).eq.lonEnd(lineInd)) then
			print("Not across 0E/360E")
				
				regionAcross0 			= False
			
				b						:= isoline@start_point(lineInd)
				e						:= b+isoline@n_points(lineInd)-1
				latSeg 					:= isoline(0,b:e)
				lonSeg 					:= isoline(1,b:e)
				
			else
				
				if (lonBegin(lineInd).eq.lonEnd(lineInd))
					; MMMM: a region across 0E/360E
					print("Across 0E/360E")
				
					regionAcross0 			= True
					
					joinOrder				= new(nLine,integer)
					joinOrder				= 0
					joinOrder(lineInd)		= 1
					
					order 					= 1
					
					latB1 					:= latBegin(lineInd)
					latE1 					= latEnd(lineInd)
					
					lonB1 					:= lonBegin(lineInd)
					lonE1 					= lonEnd(lineInd)
						
					; if the two lines join, the beginning point of line 1 
					; should join the last point of line 2
								
					searchLine 				= True
					
					do while (searchLine)
						print("Search "+order)
						order				= order+1
						
						lineSearchInd		:= ind(lineCheck.eq.False)
						
						if (.not. any(ismissing(lineSearchInd))) then
							latBSearch 			:= latEnd(lineSearchInd)
							latESearch 			:= latBegin(lineSearchInd)
													
							lonBSearch 			:= lonEnd(lineSearchInd)
							lonESearch 			:= lonBegin(lineSearchInd)
														
							lineBInd 			= ind(latBSearch.eq.latB1 .and. (abs(lonBSearch-lonB1).ge.360.))
							lineEInd 			= ind(latESearch.eq.latE1 .and. (abs(lonESearch-lonE1).ge.360.))
							
							if (.not. any(ismissing(lineBInd)) .and. .not. any(ismissing(lineEInd))) then
								
								findInd 			= lineSearchInd(lineBInd)
									
								joinOrder(findInd)	= order
								lineCheck(findInd)	= True
									
								if (lineBInd.eq.lineEInd) then		
									searchLine 		= False
								else
									latB1			:= latBegin(findInd)
									lonB1			:= lonBegin(findInd)
								end if
							
							else
								searchLine		= False						
							end if
						else
							searchLine		= False	
						end if
						
						delete(lineSearchInd)
					end do
						
					if (max(joinOrder).gt.1) then
						joinInd					:= ind(joinOrder.ge.1)					
						nJoin 					= dimsizes(joinInd)
									
						b						:= isoline@start_point(joinInd)
						e						:= b+isoline@n_points(joinInd)-1
						
						do j = 0, nJoin-1
							
							latSTmp				:= isoline(0,b(j):e(j))
							lonSTmp				:= isoline(1,b(j):e(j))
							
						; **** Add 360 to the segment(s) beginning at 0E
						; **** Necessary for finding a correct western and eastern end of a blocking region

							if (min(lonSTmp).eq.0) then
								lonSTmp 		= lonSTmp+360.
							end if
							
							if (.not. isvar("latSeg")) then
								latSeg 			= latSTmp
								lonSeg 			= lonSTmp
							else
								latSMerge 		= array_append_record(latSeg,latSTmp,0)
								lonSMerge 		= array_append_record(lonSeg,lonSTmp,0)
								delete([/latSeg,lonSeg/])
								latSeg 			= latSMerge
								lonSeg 			= lonSMerge
								delete([/latSMerge,lonSMerge/])
							end if								
							
							delete([/latSTmp,lonSTmp/])
						end do

						; Don't subtract lonSegAdjust by 360., otherwise we cannot find 
						; the western and eastern end of a region 
						
						lonSegAdjust 			:= lonSeg
						lonSeg 					= where(lonSeg.ge.360.,lonSeg-360,lonSeg)
						
						delete([/b,e,joinInd/])
					end if
				end if
			end if
			
			; 111111111111111111111111111111111111
			
			if (isvar("latSeg")) then
				
				gridCheck2D					:= gc_inout(latTwoD,lonTwoD,latSeg,lonSeg)
				gridCheck1D 				:= ndtooned(gridCheck2D)
				
				gridInInd					:= ind(gridCheck1D.eq.True)
				gridOutInd					:= ind(gridCheck1D.eq.False)
			
				; .........................................................................
				; East-west extension of a region
				
				if (.not. any(ismissing(gridInInd))) then
				
					; Check whether a region is a blocking region
					blockR 						:= blockOrig1D(gridInInd)			
					lonR 						:= lonOneD(gridInInd)
					
					if (regionAcross0) then
					
						lonRLeft 				= min(lonSegAdjust)
						lonRRight				= max(lonSegAdjust)
					
						lonRLeft 				= where(lonRLeft.ge.360.,lonRLeft-360.,lonRLeft)
						lonRRight 				= where(lonRRight.ge.360.,lonRRight-360.,lonRRight)
							
						; no grid points between lonMax and 360E
						; e.g. 359E-30E => 0-30E
						lonRLeft 				= where(lonRLeft.gt.lonMax,0.,lonRLeft) 
						
						regionWInd 				:= ind(lonR.ge.lonR(closest_val(lonRLeft,lonR)))
						regionEInd 				:= ind(lonR.le.lonR(closest_val(lonRRight,lonR)))
				
						blockWest 				= blockR(regionWInd) ; region west of 360E 
						blockEast 				= blockR(regionEInd) ; region east of 0E
					
						blockWestInd 			= ind(blockWest.eq.-1)
						blockEastInd			= ind(blockEast.eq.-1)
						
						nonBlockWInd 			= ind(blockWest.ne.-1)
						nonBlockEInd			= ind(blockEast.ne.-1)
						
						if (all(ismissing(blockWestInd)) .and. all(ismissing(blockEastInd))) then
							blockFind			= False
						else
							blockFind			= True
							
							if (all(ismissing(blockWestInd))) then ; no region west of 360E 
								lonBW			= min(lonR(regionEInd(blockEastInd)))
								lonBE 			= max(lonR(regionEInd(blockEastInd)))
							else
								if (all(ismissing(blockEastInd))) ; no region east of 0E 
									lonBW		= min(lonR(regionWInd(blockWestInd)))
									lonBE 		= max(lonR(regionWInd(blockWestInd)))
								else  ; region across 0E/360E
									lonBW		= min(lonR(regionWInd(blockWestInd)))
									lonBE 		= max(lonR(regionEInd(blockEastInd)))
								end if
							end if
						end if
						
						if (.not. any(ismissing(nonBlockWInd))) then
							gridCheck1D(nonBlockWInd) = False
						end if
					
						if (.not. any(ismissing(nonBlockEInd))) then
							gridCheck1D(nonBlockEInd) = False
						end if
					
						delete([/regionWInd,regionEInd,blockWest,blockEast,blockWestInd,blockEastInd/])
						delete([/nonBlockWInd,nonBlockEInd/])
					
					else
						lonRLeft 				= min(lonSeg)
						lonRRight 				= max(lonSeg)
						
						regionInd 				:= ind(lonR.ge.lonR(closest_val(lonRLeft,lonR)) \
												   .and. lonR.le.lonR(closest_val(lonRRight,lonR)))
						
						block					= blockR(regionInd) 
						blockInd 				= ind(block.eq.-1)
						nonBlockInd 			= ind(block.ne.-1)
						
						if (all(ismissing(blockInd))) then
							blockFind			= False
						else
							blockFind			= True
							lonBW				= min(lonR(regionInd(blockInd)))
							lonBE 				= max(lonR(regionInd(blockInd)))
						end if
						
						if (.not. any(ismissing(nonBlockInd))) then
							gridCheck1D(nonBlockInd) = False
						end if
						
						delete([/regionInd,block,blockInd,nonBlockInd/])
					end if
				
					delete([/blockR,lonR,lonRLeft,lonRRight/])
					
					; Only execute the loop if a blocking region is identified
					
					if (all(gridCheck1D.eq.False)) then
						blockFind				= False
					end if
					
					if (blockFind) then
					
						; printVarSummary(gridCheck1D)
						; printVarSummary(ZDay)
						; exit
					
						B1DInd					:= ind(gridCheck1D.eq.True)
						
						if (.not. any(ismissing(B1DInd))) then
							latR					:= latOneD(B1DInd)
							
							block					:= blockOrig1D(B1DInd)
							blockInd 				:= ind(block.eq.-1)
							
							if (.not. any(ismissing(blockInd))) then
								latBN 				= max(latR(blockInd))
								latBS 				= min(latR(blockInd))
							
								print(lonBW + "-" + lonBE + "E and " + latBS + "-" + latBN + "N")
									
								if (lonBW.gt.lonBE) then
									dLonR 				= (360.-lonBW)+lonBE
								else
									dLonR 				= lonBE-lonBW
								end if
								
								dLatR					= latBN-latBS
								
								; ....................................................
								
								areaOneD				= ndtooned(areaTwoD)
								gridArea				= areaOneD(B1DInd)
								
								; .........................................................................
								; Output potential blocking region with an area at least 10**6 km**2
												
								; if (dLonR.ge.DLON) then	
								if (dLonR.ge.DLON .and. sum(gridArea).ge.1) then	

									; **********************************************************************
									; locating blocking center using weighted average
									
									; Z1D						:= ndtooned(ZDay)
									
									; latB1D	  				:= latOneD(B1DInd)
									; lonB1D	  				:= lonOneD(B1DInd)
										
									; ZWeight 				:= sum(Z1D(B1DInd)*gridArea)/sum(gridArea)
									; ZRegion					:= Z1D(B1DInd)*cos(PI*latB1D/180.)							
									; ; ZRegion					:= Z1D(B1DInd)						
										
									; latWeight				= sum(ZRegion*latB1D)/sum(ZRegion)
										
									; if (regionAcross0) then
								
										; lonAdjust			= where(lonB1D.le.lonBE,lonB1D+360.,lonB1D)
										; lonWeight			= sum(ZRegion*lonAdjust)/sum(ZRegion)
										; lonWeight 			= where(lonWeight.ge.360.,lonWeight-360.,lonWeight)
										
										; delete(lonAdjust)
									; else
										; lonWeight			= sum(ZRegion*lonB1D)/sum(ZRegion)
									; end if
									
									; delete([/Z1D,latB1D,lonB1D/])
									
									; **********************************************************************
									; locating blocking center using maximum height within a closed region
								
									Z1D						:= ndtooned(ZDay)
									
									latB1D	  				:= latOneD(B1DInd)
									lonB1D	  				:= lonOneD(B1DInd)
									
									ZRegion 				:= Z1D(B1DInd)
									
									ZWeight					= ZRegion(maxind(ZRegion))
									latWeight				= latB1D(maxind(ZRegion))
									lonWeight				= lonB1D(maxind(ZRegion))
									
									delete([/Z1D,latB1D,lonB1D/])
									
									; **********************************************************************
									; GGGG
									; add marker
									
									if (DRAWGRAPH) then
										plotMark(cntMark)		= gsn_add_polymarker(wks,plotZ,lonWeight,latWeight,RESMARK)
									end if
									
									cntMark					= cntMark+1
									
									; **********************************************************************
									
									; Replace the original blocking grids
									
									blockR1D				= ndtooned(blockGRID)
									blockR1D(B1DInd)		= (/REGIONNUMBER/)
									blockR2D 				= onedtond(blockR1D,dimsizes(blockGRID))
									blockGRID			 	= (/blockR2D/)
											
									; ......................................................................		
									; ......................................................................		
									; ................... Output blocking info .............................		
									; ......................................................................		
									; ......................................................................	
									
									; RRRR

									; TITLE 			= "0_region 1_file_no 2_time_position_in_file 3_reference_time 4_YYYYMMDD " + \
														  ; "5_year 6_month 7_day 8_lon_west 9_lon_east 10_lat_south 11_lat_north " + \
														  ; "12_Area 13_Z_max 14_lon_center 15_lat_center"          
													
									fRegionStr 				= REGIONNUMBER + " " + numFil + " " + timeSTROUT  + " " + \
															  lonBW + " " + lonBE + " " + latBS + " " + latBN + " " + sum(gridArea) + " " + \
															  ZWeight + " " + lonWeight + " " + latWeight	
											
									REGIONNUMBER 	   		= REGIONNUMBER+1

									print(""+fRegionStr)

									; WWWW
									system("echo " + fRegionStr + " >> " + FBLOCKREGION)
									
									; ......................................................................
									
									fBRLat					= DIRBRINFO + "region_" + dateSTROUT + "_" + REGIONNUMBER + "_latitude.txt"
									fBRLon					= DIRBRINFO + "region_" + dateSTROUT + "_" + REGIONNUMBER + "_longitude.txt"
									
									asciiwrite(fBRLat,latSeg)
									asciiwrite(fBRLon,lonSeg)
										
									delete([/blockR1D,blockR2D/])
									delete([/ZRegion,ZWeight/])
										
								end if					
								delete(gridArea)
							end if
							
							delete([/latR,block,blockInd/])
						end if	
						delete(B1DInd)
					end if
				end if
				
				delete([/latSeg,lonSeg/])
				
				if (isvar("lonSegAdjust")) then
					delete(lonSegAdjust)
				end if
			end if
		end do
					
		; ***************************************************************************************************
		; GGGG
		if (DRAWGRAPH)
			draw(plotZ)
			frame(wks)
			
			delete([/plotZ,wks/])
			
			system("convert -geometry 1600x1600 -density 800x800 -trim " + wksName + ".eps " + wksName + ".png")
			system("/bin/rm -f " + wksName + ".eps")
		end if
		
		; ***************************************************************************************************
	end if
end