package com.pb.mtctm2.abm.ctramp;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.log4j.Logger;

import com.pb.common.datafile.OLD_CSVFileReader;
import com.pb.common.datafile.TableDataSet;

public class ParkingLotDataManager {

	private static ConcurrentHashMap<Integer,ParkingLot> parkingLotMap;
	private static ParkingLotDataManager instance = new ParkingLotDataManager();

    private transient Logger logger = Logger.getLogger("universityModel");

    private static byte maxSpaceType;
    private static int numberOfLots;
    
    public static ParkingLotDataManager getInstance(String lotFile, int periods){
    	
    	if(parkingLotMap==null){
    		 initializeLots(lotFile, periods);
    	}
    	return instance;
    }
    
    public ArrayList<ParkingLot> getParkingLots(){
    	
    	Collection<ParkingLot> parkingCollection = parkingLotMap.values();
    	ArrayList<ParkingLot> parkingList = new ArrayList(parkingCollection);
    	Collections.sort(parkingList); 
    	return parkingList; 
    }
    
    public byte getMaxSpaceType(){
    	return maxSpaceType;
    }
    
    public int getNumberOfLots(){
    	return numberOfLots;
    }
	/**
	 * Read the parking lot data file, initialize the lot array.
	 */
	synchronized public static void initializeLots(String lotFile, int periods){
		
		// read the lot file
		TableDataSet lotData = readFile(lotFile);
		numberOfLots = lotData.getRowCount();
				
//	 	parkingLots = new ParkingLot[numberOfLots];
		parkingLotMap = new ConcurrentHashMap<Integer,ParkingLot>();
		//initialize the model
	
		//fill in parking lot array
		for(int i = 0;i<numberOfLots;++i){
			
			int taz = (int) lotData.getValueAt(i+1,"MAZ");
			int lotType = (int) lotData.getValueAt(i+1, "informalLot");
			byte spaceType = (byte) lotData.getValueAt(i+1, "spaceType");
			double termTime = (double) lotData.getValueAt(i+1, "terminalTime");
			int spaces = (int) lotData.getValueAt(i+1,"spaces");
			
			//set max space type
			if(spaceType > maxSpaceType)
				maxSpaceType = spaceType;
			
			ParkingLot lot = new ParkingLot(periods);
			lot.setMaz(taz);
						lot.setLotType(lotType);
			lot.setSpaceType(spaceType);
			lot.setTermTime(termTime);
			lot.setTotalSpaces(spaces);		
			addLot(taz,spaceType, lot);
						
		}
	}
	
	/**
	 * Add a lot to the map
	 * @param taz
	 * @param spaceType
	 * @param lot
	 */
	public static void addLot(int taz, byte spaceType, ParkingLot lot){
		
		Integer key = ParkingLot.getParkingLotMapKey(taz,spaceType);
		parkingLotMap.putIfAbsent(key, lot);
	}
	
	/**
	 * Get a parking lot from the map.
	 * @param taz The TAZ
	 * @param spaceType The space type
	 * @return The parking lot.
	 */
	public ParkingLot getParkingLot(int taz, byte spaceType){
		
		int key = ParkingLot.getParkingLotMapKey(taz,spaceType);
		return parkingLotMap.get(key);
		
	}
	
	/**
	 * Reset the available spaces to total spaces.
	 * @param periods
	 */
	synchronized static public void resetAvailableSpaces(){
	   	Collection<ParkingLot> parkingCollection = parkingLotMap.values();
	    for(ParkingLot lot : parkingCollection){
	    	float totalSpaces = lot.getTotalSpaces();
	    	lot.setAvailableSpaces(totalSpaces);
	    }
	    	
	}
	
    /**
     * Read the file and return the TableDataSet.
     * 
     * @param fileName
     * @return data
     */
    private static TableDataSet readFile(String fileName){
    	
 	    TableDataSet data;	
        try {
        	OLD_CSVFileReader csvFile = new OLD_CSVFileReader();
        	data = csvFile.readFile(new File(fileName));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        
        return data;
    }




}
