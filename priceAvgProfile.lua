--logfile=io.open(getWorkingFolder().."\\LuaIndicators\\priceAvgProfile.txt", "w")

Settings={}
Settings.period = 150
Settings.shift = 100
Settings.Name = "*priceAvgProfile"
Settings.weeks = 0 -- 1 - текущая, отрицательное число - сколько прошлых недель, включая текущую

---------------------------------------------------------------------------------------

lines = 100
scale = 2
min_price_step = 1

function Init()
	Settings.line = {}
	for i = 1, lines do
		Settings.line[i] = {}
		Settings.line[i] = {Color = RGB(185, 185, 185), Type = TYPE_LINE, Width = 2}
	end
	
	myFFF = FFF()
	return lines
end

function OnCalculate(index)
	if index == 1 then
		DSInfo = getDataSourceInfo()     	
		min_price_step = getParamEx(DSInfo.class_code, DSInfo.sec_code, "SEC_PRICE_STEP").param_value
		scale = getSecurityInfo(DSInfo.class_code, DSInfo.sec_code).scale
	end	
	return myFFF(index, Settings)
end

---------------------------------------------------------------------------------------
function FFF()

	local cacheL={}
	local cacheH={}
    local cacheC={}
    local weeksBegin={}

	local outlines = {}
	local calculated_buffer={}
	
	return function(ind, Fsettings)

        local period = Fsettings.period or 150
        local shift = Fsettings.shift or 150
        local weeks = Fsettings.weeks or 0
        local bars = 50

		local index = ind

		if index == 1 then			
            weeksBegin = {}
            cacheL = {}
            cacheL[index] = 0			
            cacheH = {}
            cacheH[index] = 0			
            cacheC = {}
            cacheC[index] = 0			

			calculated_buffer = {}
            outlines = {}

			return nil
		end
	------------------------------		

		cacheL[index] = cacheL[index-1] 
		cacheH[index] = cacheH[index-1] 
		cacheC[index] = cacheC[index-1] 

		if not CandleExist(index) then
			return nil
		end

		cacheH[index] = H(index)
        cacheL[index] = L(index)
        cacheC[index] = C(index)
		
		if T(index).week_day<T(index-1).week_day or T(index).year>T(index-1).year then
			weeksBegin[#weeksBegin+1] = index
		end

		if index < Size() then return nil end	

		if calculated_buffer[index] ~= nil then
			return nil
		end

		for i=1,#outlines do                   		
			SetValue(index-shift-1,          i, nil)
			SetValue(index-shift,            i, nil)
			SetValue(outlines[i].index,   	 i, nil)
			
			outlines[i].index = index-shift
			outlines[i].val = nil
		end            
		
		local beginIndex = index-period
		if weeks == 1 then
			beginIndex = weeksBegin[#weeksBegin] or beginIndex
		end
		if weeks < 0 then
			beginIndex = weeksBegin[#weeksBegin+weeks] or beginIndex
		end
		
		shift = math.max(bars, index-beginIndex)

		--WriteLog('weeks '..tostring(weeks)..' last '..tostring(weeksBegin[#weeksBegin])..' beginIndex '..tostring(beginIndex))
		
		local maxPrice = math.max(unpack(cacheH,math.max(beginIndex, 1),index))
		local minPrice = math.min(unpack(cacheL,math.max(beginIndex, 1),index))       
		
		----------------------------------------
		local priceProfile = {}
		local clasterStep = math.max((maxPrice - minPrice)/lines, 5*min_price_step)

		--WriteLog('minPrice '..tostring(minPrice)..' maxPrice '..tostring(maxPrice)..' clasterStep '..tostring(clasterStep))
		
		for i = 0, (index-beginIndex) do
			if CandleExist(index-i) then				
				local barSteps = math.max(math.ceil((H(index-i) - L(index-i))/clasterStep),1)
				for j=0,barSteps-1 do
					local clasterPrice = math.floor((L(index-i) + j*clasterStep)/clasterStep)*clasterStep
					local clasterIndex = clasterPrice*math.pow(10, scale)
					if priceProfile[clasterIndex] == nil then
						priceProfile[clasterIndex] = {price = clasterPrice, vol = 0}
					end
					priceProfile[clasterIndex].vol = priceProfile[clasterIndex].vol + V(index-i)/barSteps
				end
			end
		end

		--------------------
		local MAXV = 0
		local maxPrice = 0
		local maxCount = 0 

		local sortedProfile = {}

		for i, profileItem in pairs(priceProfile) do
			MAXV=math.max(MAXV,profileItem.vol)
			if MAXV == profileItem.vol then
				maxPrice=profileItem.price
			end
			maxCount = maxCount + 1
			sortedProfile[maxCount] = {price = profileItem.price, vol = profileItem.vol}
		end
				
		--WriteLog('maxV '..tostring(MAXV)..' tblMax '..tostring(sortedProfile[1].vol))

		if maxPrice == 0 then
			maxPrice = O(index) 
		end

		table.sort(sortedProfile, function(a,b) return (a['vol'] or 0) > (b['vol'] or 0) end)

		---------------------
		for i=1,lines do                                        

			outlines[i] = {index = index-shift+bars, val = maxPrice}

			if sortedProfile[i]~=nil then				
				sortedProfile[i].vol=math.floor(sortedProfile[i].vol/MAXV*bars)
				if sortedProfile[i].vol>0 then
					outlines[i].index = index-shift+sortedProfile[i].vol
					outlines[i].val = sortedProfile[i].price                           
				end                                               
			end                   
			SetValue(index-shift,       i, outlines[i].val)
			SetValue(outlines[i].index, i, outlines[i].val)
					
			--WriteLog('line '..tostring(i).." price "..tostring(GetValue(index-shift, i)).." - "..tostring(GetValue(outlines[i].index, i)).." vol "..tostring(outlines[i].index-index+shift))
				
		end                

		calculated_buffer[index] = true
				
		return nil
	end
end

function WriteLog(text)

    logfile:write(tostring(os.date("%c",os.time())).." "..text.."\n");
    logfile:flush();
    LASTLOGSTRING = text;
 
end
