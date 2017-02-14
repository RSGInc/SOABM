package com.pb.mtctm2.abm.ctramp;

public class ParkingLot implements Comparable<ParkingLot> {
	
	int maz;
	byte spaceType;
	int lotType;
	float totalSpaces; 
	float[] availableSpaces; //available spaces by period
	double lotTermTime;
	float[] shadowPrice;   //an array of prices by market segment and time period; period is 0-initialized
	
	/**
	 * Constructor.
	 */
	public ParkingLot(int periods){
		
		//initialize shadow price array
		shadowPrice = new float[periods];
		availableSpaces = new float[periods];
		
	}
	
	
	/**
	 * Set total parking spaces for the lot; also set available spaces through the day.
	 * 
	 * @param marketSegment
	 * @param spaces  Total spaces
	 */
	public void setTotalSpaces(float spaces){
		
		totalSpaces = spaces;
		for(int i = 0; i < availableSpaces.length;++i)
			availableSpaces[i]  = spaces;
			
	}
	
	/**
	 * Get total parking spaces for the lot
	 * 
	 * @return Total spaces
	 */
	public float getTotalSpaces(){
		
		return totalSpaces;
	}
			
	/**
	 * Set shadow price for time period.
	 * 
	 * @param timePeriod  1-initialized in method argument.
	 * @param price  Shadow price to set
	 */
	public void setShadowPrice(int timePeriod, float price){
		
		shadowPrice[timePeriod-1] = price;
	}
	
	
	/**
	 * Set available spaces for time period
	 * 
	 * @param timePeriod Time period to set spaces for (1-initialized)
	 * @param availableSpaces Available spaces to set in lot
	 */
	public void setAvailableSpaces(int timePeriod, float availableSpaces){
		
		this.availableSpaces[timePeriod-1] = availableSpaces;
		
	}
	
	/**
	 * Set available spaces in lot for all periods to value.
	 * 
	 * @param availableSpaces Total spaces to set.
	 */
	public void setAvailableSpaces(float availableSpaces){
		for(int i = 0; i<this.availableSpaces.length;++i)
			this.availableSpaces[i]=availableSpaces;
	}
	
	/**
	 * Get available spaces for time period.
	 * 
	 * @param timePeriod  1-initialized in method argument.
	 * return Available spaces
	 */
	public float getAvailableSpaces(int timePeriod){
		
		return availableSpaces[timePeriod-1];
	}
	/**
	 * Decrease available spaces for time period.
	 * 
	 * @param beginPeriod  begin time period of trip (1-initialized) .
	 * @param endPeriod  end time period of trip (1-initialized) .
	 */
	public void decreaseAvailableSpaces(int beginPeriod, int endPeriod, float demand){
		--beginPeriod;
		--endPeriod;
		for(int i = beginPeriod; i <=endPeriod;++i)
			availableSpaces[i] = availableSpaces[i] - demand;
	}
	
	/**
	 * Get shadow price for time period.
	 * 
	 * @param timePeriod  1-initialized in method argument.
	 * return Shadow price
	 */
	public float getShadowPrice(int timePeriod){
		
		return shadowPrice[timePeriod-1];
	}
	/**
	 * @return the maz
	 */
	public int getMaz() {
		return maz;
	}

	/**
	 * @param taz the maz to set
	 */
	public void setMaz(int maz) {
		this.maz = maz;
	}
	/**
	 * @return the spaceType
	 */
	public byte getSpaceType() {
		return spaceType;
	}

	/**
	 * @param spaceType the spaceType to set
	 */
	public void setSpaceType(byte spaceType) {
		this.spaceType = spaceType;
	}		
	/**
	 * @return the lotType
	 */
	public int getLotType() {
		return lotType;
	}

	/**
	 * @param lotType the lotType to set
	 */
	public void setLotType(int lotType) {
		this.lotType = lotType;
	}		
	/**
	 * @return the lot terminal time
	 */
	public double getTermTime() {
		return lotTermTime;
	}

	/**
	 * @param set the lot terminal time
	 */
	public void setTermTime(double lotTermTime) {
		this.lotTermTime = lotTermTime;
	}

	/**
	 * Calculate a key for the parking lot hashmap.
	 * @param maz  parking MAZ
	 * @param spaceType space type
	 * @return A key for the map.
	 */
	public static int getParkingLotMapKey(int maz, byte spaceType){
		
		return maz*1000+spaceType;
	}


	/**
	 * @Override
	 * 
	 * 
     * Return a negative value if this object is smaller than the other object
     * Return 0 (zero) if this object is equal to the other object.
     * Return a positive value if this object is larger than the other object.
	 */
	public int compareTo(ParkingLot compareLot) {
		
		int thisKey = ParkingLot.getParkingLotMapKey(this.maz, this.spaceType);
		int compareKey = ParkingLot.getParkingLotMapKey(compareLot.maz, compareLot.spaceType);
		
		if(thisKey < compareKey)
			return -1;
		else if(thisKey > compareKey)
			return 1;
		
		return 0;
	}	

	
}
