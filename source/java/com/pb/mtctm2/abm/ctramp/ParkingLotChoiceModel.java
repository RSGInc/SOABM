package com.pb.mtctm2.abm.ctramp;

import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.log4j.Logger;

import com.pb.common.datafile.OLD_CSVFileReader;
import com.pb.common.datafile.TableDataSet;
import com.pb.common.math.MersenneTwister;
import com.pb.common.util.PropertyMap;
import com.pb.mtctm2.abm.accessibilities.BestTransitPathCalculator;
import com.pb.mtctm2.abm.accessibilities.BuildAccessibilities;
import com.pb.mtctm2.abm.accessibilities.NonTransitUtilities;

public class ParkingLotChoiceModel {

    private static final String PROPERTIES_MODEL_OFFSET         = "UniversityParkingLotChoiceModel.RNG.offset";
	private static final String PROPERTIES_RUNMODEL             = "UniversityParkingLotChoiceModel.RunModel";
	public static final String PROPERTIES_LOTFILE               = "UniversityParkingLotChoiceModel.ParkingLots.file";
	public static final String PROPERTIES_PRICEFILE             = "UniversityParkingLotChoiceModel.ParkingPrices.file";
	public static final String PROPERTIES_DAMPINGFACTOR         = "UniversityParkingLotChoiceModel.ParkingPriceDampingFactor";
	private static final String PROPERTIES_TRANSITCONSTANT      = "UniversityParkingLotChoiceModel.TransitConstant";
	private static final String PROPERTIES_UTIL_LD              = "UniversityParkingLotChoiceModel.Util_LD";
	private static final String PROPERTIES_INFORMALCONSTANT     = "UniversityParkingLotChoiceModel.InformalParkingConstant";
	private static final String PROPERTIES_IVTCOEFF             = "UniversityParkingLotChoiceModel.IVTCoefficient";
	private static final String PROPERTIES_SEGMENTCONST         = "UniversityParkingLotChoiceModel.SpaceTypesConstants.";
	private static final String PROPERTIES_SIMULATION           = "UniversityParkingLotChoiceModel.SimulationModel";
	private static final String PROPERTIES_UNMETDEMANDFILE      = "UniversityParkingLotChoiceModel.UnmetParkingDemand.file";
	private static final byte parkingPurpose = 21;
	public static final String  PROPERTIES_OUTPUT_PARKING_FILE  = "Results.UniversityParkingDataFile";
	
	private TazDataManager                    tazManager;  
	
	// other objects
	private HashMap<String,String> propertyMap;
    private transient Logger logger = Logger.getLogger("universityModel");
    
  //  private Purposes purposes;
	private long randomOffset = 19893782;
	private MersenneTwister random;
	private float occupancyThreePlus = 3.3f;

	public final static int PARKING_SEGMENTS=3;
	public final static int FACULTYSTAFF_SEGMENT = 0;
	public final static int STUDENT_SEGMENT = 1;
	public final static int VISITOR_SEGMENT = 2;
	public final static String[] parkingSegmentNames = {"facultyStaff","student","visitor"};
	
 //	private ParkingLot[] parkingLots;
	private static ParkingLotDataManager parkingLotDataManager;
	
	private double[] expUtilities;
    private int periods;             // total number of periods
	private boolean runModel;
	private boolean simulationModel;  //if true, uses explicit simulation to choose lots; filled up lots will be skipped
	private double transitConstant;
	private double ivtCoeff;
	private double utilLdCoeff;
	private float[] informalParkConstant;
	private double[][][] parkingPenalties;   //by destination TAZ, time period, segment
	private double dampingFactor;
	
	private float[][] segmentConst;          //rectangular array of segments, all space types; first dimension = segments, second dimension = space types 
	private byte maxSpaceType;
    ArrayList<Integer> parkingDestinations;
    private int iteration=0;
    private float sampleRate;
    
 	static int[][] unmetDemand;  //dimensioned by parking segments, time periods
    private ModelStructure modelStructure;
    private McLogsumsCalculator logsumHelper;
    private BestTransitPathCalculator  bestPathCalculator;
    private NonTransitUtilities ntUtilities;
    private float totalDemand;
    private MgraDataManager mgraDataManager;
    
	/**
	 * Default constructor.
	 */
	public ParkingLotChoiceModel(HashMap<String,String> propertyMap, ModelStructure modelStructure, int iteration, ArrayList<Integer> parkingDestinations, float sampleRate){
		
		//don't do anything if runModel is not true
		runModel = PropertyMap.getBooleanValueFromPropertyMap(propertyMap, PROPERTIES_RUNMODEL);
		simulationModel =  PropertyMap.getBooleanValueFromPropertyMap(propertyMap, PROPERTIES_SIMULATION);
		this.propertyMap = propertyMap;
		if(!runModel)
			return;
		this.modelStructure = modelStructure;
		this.iteration = iteration;
	 	periods  = modelStructure.MAX_TOD_INTERVAL;
	 	
	 	dampingFactor = PropertyMap.getFloatValueFromPropertyMap(propertyMap, PROPERTIES_DAMPINGFACTOR);
	 
 	   //for parking simulation model; track unmet demand
	   if(unmetDemand==null) unmetDemand = new int[PARKING_SEGMENTS][periods];
	   
	   this.parkingDestinations = parkingDestinations;
	   this.sampleRate = sampleRate;
	   
	   logger.info("University parking destinations");
	   for(int i = 0; i< parkingDestinations.size();++i)
		   logger.info(" "+i+": "+parkingDestinations.get(i));
	   
	   mgraDataManager = MgraDataManager.getInstance(propertyMap);
	 	
 	}
	
	public static ParkingLotDataManager getParkingLotDataManager(){
		return parkingLotDataManager;
	}
	
	/**
	 * Set up the model.
	 */
	public void setup(){
		
		//don't do anything if runModel is not true
		runModel = PropertyMap.getBooleanValueFromPropertyMap(propertyMap, PROPERTIES_RUNMODEL);
		if(!runModel)
			return;

        // create a new accessibilities object for lot choice accessibilities
        ntUtilities = new NonTransitUtilities(propertyMap);
	    logsumHelper = new McLogsumsCalculator();
	    logsumHelper.setupSkimCalculators(propertyMap);
	    bestPathCalculator = logsumHelper.getBestTransitPathCalculator();
 
        String lotFile =  PropertyMap.getStringValueFromPropertyMap(propertyMap, PROPERTIES_LOTFILE);
        String priceFile =  PropertyMap.getStringValueFromPropertyMap(propertyMap, PROPERTIES_PRICEFILE);
        
        parkingLotDataManager = ParkingLotDataManager.getInstance(lotFile, periods);
        
        maxSpaceType = parkingLotDataManager.getMaxSpaceType();
        int numberOfLots = parkingLotDataManager.getNumberOfLots();
        
		expUtilities = new double[numberOfLots];

		//calculate boolean array of canPark
		calculateSegmentConstantsArray();

		//parking file from the last iteration
        int lastIteration =1;
        if(iteration>1)
        	lastIteration = iteration -1;
        
        String parkingFile = formFileName(propertyMap.get(PROPERTIES_OUTPUT_PARKING_FILE), lastIteration);
                
        if(simulationModel)
        	calculateLotAvailabilityByPeriod(parkingFile);
        else
        	readPrices(priceFile);

        
        random = new MersenneTwister();

   		randomOffset = PropertyMap.getLongValueFromPropertyMap(propertyMap,
   				PROPERTIES_MODEL_OFFSET);
            
        transitConstant = PropertyMap.getFloatValueFromPropertyMap(propertyMap, PROPERTIES_TRANSITCONSTANT);
        informalParkConstant = PropertyMap.getFloatArrayFromPropertyMap(propertyMap, PROPERTIES_INFORMALCONSTANT);
        ivtCoeff = (double) PropertyMap.getFloatValueFromPropertyMap(propertyMap, PROPERTIES_IVTCOEFF);
        utilLdCoeff = (double) PropertyMap.getFloatValueFromPropertyMap(propertyMap, PROPERTIES_UTIL_LD);

        if (parkingPenalties == null){
    		parkingPenalties = setParkingPenalty();
        }
        
	
	}
	

	
	/*
	 * Read property file, get the space types for each parking segment, and set the canPark array.
	 */
	private void calculateSegmentConstantsArray(){
		
		segmentConst = new float[parkingSegmentNames.length][maxSpaceType+1];
		
        //initialize the available lot types array
        for(int i = 0; i < parkingSegmentNames.length;++i){
        	float[] segConstant = PropertyMap.getFloatArrayFromPropertyMap(propertyMap, PROPERTIES_SEGMENTCONST+parkingSegmentNames[i]);
        	
        	//set the float array based on the parking type constants.
        	for(int j = 0; j < maxSpaceType;++j){
        		segmentConst[i][j] = segConstant[j];
        	}
        }
		
	}
	
	/**
	 * Read shadow prices from a file.
	 * 
	 * @param priceFile
	 */
	public void readPrices(String priceFile){
		
		if(new File(priceFile).isFile()){
			
			TableDataSet priceData = readFile(priceFile);
	
			int numberOfLots = priceData.getRowCount();

			int lotsInMap = parkingLotDataManager.getNumberOfLots();
			
			if(numberOfLots!=lotsInMap){
				logger.fatal("Error: Not same number of lots in parking lot price file "+priceFile+" as in parking lot file");
				throw new RuntimeException();
			}
			
			for(int row = 1; row < priceData.getRowCount();++row){
				
				int taz = (int) priceData.getValueAt(row,"TAZ");
				byte spaceType = (byte) priceData.getValueAt(row, "spaceType");

				ParkingLot lot = parkingLotDataManager.getParkingLot(taz,spaceType);
				
				//through periods
				for(int j = 0; j < periods; ++ j){
					float price = priceData.getValueAt(row,"Price_"+(j+1));
					lot.setShadowPrice(j+1, price);
				}
			}
			
		}else{
			logger.info("File "+priceFile+" does not exist, no parking lot shadow pricing in this iteration");
		}
	}
	
	
	/**
	 * Calculate available spaces per lot based on a previous model run; used in the calculation of destination costs
	 * which influence mode choice.
	 *  
	 * @param parkingDemandFile  A demand file of demand per lot from a previous run
	 */
	public void calculateLotAvailabilityByPeriod(String parkingDemandFile){
	
		if(!runModel)
			return;

		if(!new File(parkingDemandFile).isFile()){
			
			logger.info("No demand data found. Available spaces will not be calculated");
			return;
		}
		
		TableDataSet demandData = readFile(parkingDemandFile);

		//iterate through lots
	   ArrayList<ParkingLot> parkingLots = parkingLotDataManager.getParkingLots();
	  
		for(ParkingLot lot : parkingLots){
			
			int taz = lot.getMaz();
			byte spaceType = lot.getSpaceType();
			float totalSpaces =  lot.getTotalSpaces();
		
			//get demand
			float[] demand = getTotalDemandForLotByPeriod(demandData,taz,spaceType);
			
			//iterate through periods and set available spaces
			for(int k  = 0; k < periods; ++k){
			
				int availableSpaces = (int) Math.max(totalSpaces-demand[k], 0);
				
				lot.setAvailableSpaces(k+1,availableSpaces);
			}
			
		}

	}
	
	
	
	
	/**
	 * Calculate shadow prices. First, copy the existing parking shadow price file to priceFile.old. Then calculate new shadow prices
     * based upon the estimated vehicle demand at each lot, add to old prices, and write out the prices to the shadow price file.
	 * 
	 * @param parkingDemandFile
	 * @param lotFile
	 * @param priceFile
	 */
	public void calculateShadowPrices(String parkingDemandFile, String lotFile, String priceFile){

		if(!runModel)
			return;

		if(!new File(parkingDemandFile).isFile()){
			
			logger.info("No demand data found, no shadow prices will be calculated");
			return;
		}
		
		//don't calculate prices if running the simulation model
		if(simulationModel)
			return;

        //copy price file to old file if it exists
   		if(new File(priceFile).isFile()){
    
   			Path source = Paths.get(priceFile);
   			Path target = Paths.get(priceFile+".old");
   			try{
   				Files.copy(source, target, REPLACE_EXISTING);
   			} catch (InvalidPathException e) {
   				logger.error("Can't find source file "+priceFile+" for copying!");
   				throw new RuntimeException();
   			} catch (SecurityException e) {
   				logger.error("Access denied trying to copy "+priceFile+"to "+priceFile+".old!");
   				throw new RuntimeException();
   			} catch (IOException e) {
   				logger.error("Error occured trying to copy "+priceFile+"to "+priceFile+".old!");
   				throw new RuntimeException();
   			}
    
  		}

		TableDataSet demandData = readFile(parkingDemandFile);
		TableDataSet lotData = readFile(lotFile);
		
		//get max space type
		int numberOfLots = lotData.getRowCount();
			
		float[][] price  = new float[periods][numberOfLots];
	
		TableDataSet oldPriceData = null;

		if(new File(priceFile).isFile()){
			
			oldPriceData = readFile(priceFile);

		}
		
		int[] tazs = new int[lotData.getRowCount()];
		int[] spaceTypes = new int[lotData.getRowCount()];
		
		//iterate through lots
		for(int i = 0; i<numberOfLots; ++i){
			int taz = (int) lotData.getValueAt(i+1,"TAZ");
			byte spaceType = (byte) lotData.getValueAt(i+1, "spaceType");
			float spaces =  lotData.getValueAt(i+1,"Spaces");
		
			//get demand
			float[] demand = getTotalDemandForLotByPeriod(demandData,taz,spaceType);

			//save taz and space types so that we can use the array to create the output TableDataSet
			tazs[i] = taz;
			spaceTypes[i] = spaceType;

			//get the existing price
			float[] existingPrice = new float[demand.length];
			if(oldPriceData != null)
				existingPrice = getPriceData(oldPriceData,taz,spaceType);
				
			//iterate through periods
			for(int k  = 0; k < periods; ++k){
					
				//calculate new price if lot is over capacity or if there is a shadow price already and demand is greater than 0.
				if(demand[k] > 0.95*spaces || (existingPrice[k]<0 && demand[k]>0)){
					price[k][i] = (float) (Math.log(spaces/demand[k]) * dampingFactor);
				
					if(demand[k]-spaces>=1){
						logger.warn("Lot "+taz+" over capacity by "+Math.floor(demand[k]-spaces)+" vehicles in period "+(k+1));
					}
					
					//add the existing price to the shadow price so it converges
					price[k][i] += existingPrice[k];
				}
			}
			
		}
		
		//create new shadow price data file and append the TAZ column to it
		TableDataSet newPriceData = new TableDataSet();
		newPriceData.appendColumn(tazs, "TAZ");
		newPriceData.appendColumn(spaceTypes, "spaceType");
		
		//iterate through periods and append prices
		for(int k  = 0; k < periods; ++k){

			//append the price column for the lot and period
			newPriceData.appendColumn(price[k], "Price_"+(k+1));
		}
		//write the price file
		newPriceData.writeFile(priceFile, newPriceData);
	}
	
	
	/**
	 * Fill up an array with the data for the parking model segment,
	 * and return the array, which is indexed by time period.
	 * 
	 * @param demandData   A tableDataSet of parking lot price data, with fields TAZ, spaceType,and a field price_i for each period i
	 *                     where i is the time period
	 * @param tazNumber    TAZ number to look up in the lot data
	 * @param spaceType    The space type to look up in the lot data
	 * @return             An array indexed by number of periods, 0-initialized, filled up with price data from the file
	 */
	private float[] getPriceData(TableDataSet priceData, int tazNumber, byte spaceType){
		
		float[] data = new float[periods];
		
		//find the lot in the data
		int rowNumber = 0;
		for(int i = 1; i <= priceData.getRowCount();++i ){
			
			int rowTaz = (int) priceData.getValueAt(i,"TAZ");
			byte rowSpaceType = (byte) priceData.getValueAt(i,"spaceType");
			
			if(rowTaz == tazNumber && rowSpaceType == spaceType){
				rowNumber = i;
				break;
			}
		}
		
		//if the TAZ\space type combination are not available in parking demand data, throw a warning
		if(rowNumber==0){
			logger.warn("Warning: Could not find TAZ "+tazNumber+" space type "+spaceType+" in price data; returning 0 prices");
			return data;
		}
		
		for(int i = 1; i < periods;++i){
			data[i-1] += priceData.getValueAt(rowNumber,"price_"+i);
		}
		
		return data;
	}
	
	/**
	 * Calculate total demand across all segments for a lot for each period,
	 * and return the array, which is indexed by time period.
	 * 
	 * @param demandData   A tableDataSet of parking lot data, with fields for taz, spaceType, and segment_i
	 *                     where segment corresponds to the parkingLotSegments and i corresponds to time periods 1 through n
	 * @return             An array indexed by number of periods, 0-initialized, filled up with data from the file
	 */
	private float[] getTotalDemandForLotByPeriod(TableDataSet demandData, int tazNumber, byte spaceType){
		
		float[] data = new float[periods];

		//find the lot in the data
		int rowNumber = 0;
		for(int i = 1; i <= demandData.getRowCount();++i ){
			
			int rowTaz = (int) demandData.getValueAt(i,"TAZ");
			byte rowSpaceType = (byte) demandData.getValueAt(i,"spaceType");
			
			if(rowTaz == tazNumber && rowSpaceType == spaceType){
				rowNumber = i;
				break;
			}
		}
		
		//if the TAZ\space type combination are not available in parking demand data, throw a warning
		if(rowNumber==0){
			logger.warn("Warning: Could not find TAZ "+tazNumber+" space type "+spaceType+" in demand data; returning 0 demand");
			return data;
		}
		
		//found row, fill up the array.
		for(String segmentName : parkingSegmentNames){
			
			for(int i = 1; i < periods;++i){
				data[i-1] += demandData.getValueAt(rowNumber,segmentName+"Demand_"+i);
			}
		}
		
		return data;
	}

	
    /**
     * Read the file and return the TableDataSet.
     * 
     * @param fileName
     * @return data
     */
    private TableDataSet readFile(String fileName){
    	
    	logger.info("Begin reading the data in file " + fileName);
	    TableDataSet data;	
        try {
        	OLD_CSVFileReader csvFile = new OLD_CSVFileReader();
        	data = csvFile.readFile(new File(fileName));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        
        logger.info("End reading the data in file " + fileName);
        return data;
    }

	
    /**
     * Choose a parking lot and set in tour object
     *  
     * @param household
     * @param person
     * @param tour
     */
	public void setLotZone(Household household, Person person, Tour tour){
		
		ParkingLot lotChosen = chooseLotZone(household, person, tour);
		tour.setTourParkMgra(lotChosen.getMaz());
		tour.setTourParkSpaceType(lotChosen.getSpaceType());
	}
	
	/**
	 * Choose the lot taz for the tour.
	 * 
	 * @param household  Household object
	 * @param person     Person object
	 * @param tour       Tour object with primary destination and departure period chosen
	 * @return           The selected parking lot; returns null if a lot cannot be found (no capacity for time period and market segment)
	 */
	public ParkingLot chooseLotZone(Household household, Person person, Tour tour){

		if(!runModel)
			return null;
		
		Arrays.fill(expUtilities, 0f);
		double totalExpUtility = 0f;
		
		int originMaz = tour.getTourOrigMgra();
		int destinationMaz = tour.getTourDestMgra();
		int departPeriod = tour.getTourDepartPeriod();
		
		//following code for debugging
		double[] originToLotUtilities = null;
		double[] lotToDestinationUtilities = null;
		double[] shadowPrices = null;
		double[] spaces = null;
		ParkingLot chosenLot = null;
		
		int totalLots = parkingLotDataManager.getNumberOfLots();
		
		if(household.getDebugChoiceModels()){
		
			originToLotUtilities = new double[totalLots];
			lotToDestinationUtilities = new double[totalLots];
			shadowPrices = new double[totalLots];
			spaces = new double[totalLots];
		
			logger.info("**************************************************************");
			logger.info("Parking lot choice model");
			household.logHouseholdObject("Parking lot choice model household",logger);
			person.logPersonObject(logger, 100);
			tour.logTourObject(logger, 100);
			logger.info("");
			logger.info("Begin calculating origin to lot and lot to destination utilities");
			logger.info("");
		}
		double totalAvailableSpaces = 0;
		byte parkingSegment = 0;

		// iterate through lots, calculate utility
		//iterate through lots
		int i = -1;
		ArrayList<ParkingLot> parkingLots = parkingLotDataManager.getParkingLots();
		
		for(ParkingLot lot : parkingLots){
			++i;
			int lotTaz = lot.getMaz();
			byte spaceType = lot.getSpaceType();
			double totalSpacesInLot = lot.getTotalSpaces();
			double termTime = lot.getTermTime();

			// get the total spaces for the market segment
			float informalConstant = 0f;
	
			if(person.isMajorUniversityWorker()){
				informalConstant = informalParkConstant[0];
				parkingSegment = 0;
			}
			else if(person.isMajorUniversityStudent()){				
				informalConstant = informalParkConstant[1];
				parkingSegment = 1;
			}
			else{
				informalConstant = informalParkConstant[2];
				parkingSegment = 2;
				
			}
			float segmentConstant = segmentConst[parkingSegment][spaceType];
			//if there are no spaces or the lot is irrelevant for the person, skip
			if(totalSpacesInLot==0){
				expUtilities[i]=0f;	
				continue;
			}
			//if we are running the simulation model and the lot is full, skip
			if(simulationModel && lot.getAvailableSpaces(departPeriod)<=0){
				expUtilities[i]=0f;	
				continue;
			}
			totalAvailableSpaces += lot.getAvailableSpaces(departPeriod);
		
			//get the shadow price for the market segment
			double shadowPrice = 0f;
			shadowPrice = lot.getShadowPrice(departPeriod);
			
			//calculate utilities
			double originToLotUtility = getOriginToLotUtility(originMaz, lotTaz, household.getDebugChoiceModels());
			double lotToDestinationUtility = getLotToDestinationUtility(lotTaz, destinationMaz,household.getDebugChoiceModels());
			int informal = lot.getLotType();
			double expUtility = Math.exp(segmentConstant + originToLotUtility + utilLdCoeff*lotToDestinationUtility + shadowPrice + informalConstant*informal + 4.0*ivtCoeff*termTime)*totalSpacesInLot;
			expUtilities[i] = expUtility;
			totalExpUtility += expUtility;
			
			//save stuff for debugging
			if(household.getDebugChoiceModels()){
				originToLotUtilities[i] = originToLotUtility;
				lotToDestinationUtilities[i] = lotToDestinationUtility;
				shadowPrices[i]=shadowPrice;
				spaces[i] = totalSpacesInLot;
			}
		}
		
		// no available spaces
		if(simulationModel && ((totalAvailableSpaces <= 0)||(totalExpUtility==0)) ){
			
			logger.warn("No available parking spaces for household: "+household.getHhId()+" person "+person.getPersonNum()+" tour "+tour.getTourId()+ " departing in period "+tour.getTourDepartPeriod());
			
			int tourMode = tour.getTourModeChoice();
			float occupancy = 1.0f;
			if(modelStructure.getTourModeIsS2(tourMode))
				occupancy = 2.0f;
			else if (modelStructure.getTourModeIsS3(tourMode))
				occupancy=occupancyThreePlus;
			 
			float expansionFactor = 1.0f/sampleRate;
			float demand = expansionFactor/occupancy; 
			unmetDemand[parkingSegment][tour.getTourDepartPeriod()] += demand;
			
			//return null
			return null;
		}

		long seed = household.getSeed() + randomOffset + 58 * ((int) tour.getHhId());
		random.setSeed(seed);
		double rn = random.nextDouble();
		double cumProbability = 0f;
		int parkingTaz = 0;
		byte spaceType;

		//header record for logging
		if(household.getDebugChoiceModels()){
			logger.info("******");
			logger.info("Parking lot choice model");
			household.logHouseholdObject("Parking lot choice debug log", logger);
			person.logPersonObject(logger, 100);
			tour.logTourObject(logger, 100);
			logger.info("Choosing lot with random number "+rn);
			logger.info("****");
			logger.info("LotTAZ  SpaceType  util_il util_ld shadowPrice termTime totalSpaces expUtility prob cumProb");		
			logger.info("");
		}
		
		// iterate through lots, calculate probability, choose one
		i = -1;
		parkingLots = parkingLotDataManager.getParkingLots();
		for(ParkingLot lot : parkingLots){
			++i;
			double probability = expUtilities[i]/totalExpUtility;
			cumProbability += probability;
			double termTime = lot.getTermTime();	
			if(household.getDebugChoiceModels()){
				logger.info(
				"  "+lot.getMaz()
				+"  "+lot.getSpaceType()
				+"  "+String.format("%6.2f",originToLotUtilities[i])
				+"  "+String.format("%6.2f",utilLdCoeff*lotToDestinationUtilities[i])
				+"  "+String.format("%6.2f",shadowPrices[i])
				+"  "+String.format("%6.2f",termTime)
				+"  "+String.format("%6.2f",spaces[i])
				+"  "+String.format("%6.2f",expUtilities[i])
				+"  "+String.format("%6.4f",probability)
				+"  "+String.format("%6.4f",cumProbability)
				);
			}
			if(rn<cumProbability){
				parkingTaz = lot.getMaz();
				spaceType = lot.getSpaceType();
				chosenLot = lot;
				if(household.getDebugChoiceModels()){
					logger.info("Chose lot "+i+" in TAZ "+parkingTaz+" for Space Type "+spaceType);
				}
				break;
			}

		}
		
		// no parking lot found: error
		if(parkingTaz==0){
			
			logger.fatal("Failed to find parking lot for:");
			household.logHouseholdObject("Parking lot choice debug",logger);
			person.logPersonObject(logger,100);
			tour.logTourObject(logger, 100);
			logger.fatal("Total lots = "+totalLots);
			logger.fatal("Random number "+rn);
			
			if(totalLots>0){
				cumProbability=0;
				logger.info("****");
				logger.info("LotTAZ  SpaceType termTime totalSpaces expUtility prob cumProb");		
				logger.info("");
				parkingLots = parkingLotDataManager.getParkingLots();
				i=-1;
				for(ParkingLot lot : parkingLots){
					++i;
					double probability = expUtilities[i]/totalExpUtility;
					cumProbability += probability;
					double termTime = lot.getTermTime();	
					logger.info(
						"  "+lot.getMaz()
						+"  "+lot.getSpaceType()
						+"  "+String.format("%6.2f",termTime)
						+"  "+lot.getTotalSpaces()
						+"  "+String.format("%6.2f",expUtilities[i])
						+"  "+String.format("%6.4f",probability)
						+"  "+String.format("%6.4f",cumProbability)
						);
				}
			}
			logger.fatal("Check total spaces for market segment and shadow price for departure period in parking lot data");
			throw new RuntimeException();
		}
		return chosenLot;
	}
	
	/**
	 * Get the logsum from the lot TAZ to the destination TAZ across walk and walk-transit modes.
	 * @param lotTaz
	 * @param destinationTaz
	 * @return The logsum
	 */
	public double getLotToDestinationUtility(int lotTaz, int destinationTaz, boolean debug){
	       // DMUs for this UEC
        TransitWalkAccessDMU walkDmu = new TransitWalkAccessDMU();
        // calculate walk-transit exponentiated utility
        // determine the best transit path, which also stores the best utilities array and the best mode
        bestPathCalculator.findBestWalkTransitWalkTaps(walkDmu, TransitWalkAccessUEC.MD, lotTaz, destinationTaz, false, logger);
        // sum the exponentiated utilities over modes
        double opWTExpUtility = 0;
        double[] walkTransitWalkUtilities = bestPathCalculator.getBestUtilities();
        for (int k=0; k < walkTransitWalkUtilities.length; k++){
            if ( walkTransitWalkUtilities[k] > -500 )
                opWTExpUtility += Math.exp(walkTransitWalkUtilities[k]);
        }

		double lotToDestinationWalkExpUtility = ntUtilities.getNMotorExpUtility(lotTaz,destinationTaz, ntUtilities.OFFPEAK_PERIOD_INDEX);
	
		double logsum = lotToDestinationWalkExpUtility + Math.exp(transitConstant) * opWTExpUtility;
		logsum = Math.log(logsum);
		
		return logsum;
	}
	
	
	
	/**
	 * Get the logsum from the origin MAZ to the lot MAZ.
	 * @param originMaz   The origin MAZ
	 * @param lotMaz      The lot MAZ
	 * @return The logsum or composite utility of travel between the origin and the lot
	 */
	public double getOriginToLotUtility(int originMaz, int lotMaz, boolean debug){
		
		int originTaz = mgraDataManager.getTaz(originMaz);
		int lotTaz = mgraDataManager.getTaz(lotMaz);
		
		double sovExpUtility = ntUtilities.getSovExpUtility(originTaz,lotTaz, ntUtilities.OFFPEAK_PERIOD_INDEX);
		double sovUtility=-999;
		if(sovExpUtility>0)
			sovUtility = Math.log(sovExpUtility);
		return sovUtility;
		
	}
	
	
	/**
	 * Set the values in the parkingPenalties array for each destination TAZ, time period, and market segment.
 	 * @return A 3-d array whose dimensions are tazs(internal starting at 0), periods, and parking segments.
	 */
	public double[][][] setParkingPenalty(){
 
		tazManager = TazDataManager.getInstance(propertyMap);
		int[] tazs = tazManager.getTazs();
		
		double[][][] parkPenalties  = new double[tazs.length][periods][parkingSegmentNames.length];
		boolean debug = false;
		
		for(int i=0; i < parkingSegmentNames.length; ++i){
			for(int j = 0; j < periods; ++j){
				for (int k=0; k < parkingDestinations.size(); ++k){
					int taz = parkingDestinations.get(k);
					parkPenalties[taz][j][i]= (double) calculateParkingPenalty(taz, j+1, i, debug);
				}
			}
		}
		return parkPenalties;
	}
	
	
	/**
	 * Get a list of zones that are eligible parking destinations from the size term array that is passed into
	 * the method.
	 * 
	 * @param tazSizeTerms An array of size terms for the purpose that is relevant for the parking model.
	 * @return an array containing eligible destinations for parking
	 */
	private int[] getParkingDestinations(double[] tazSizeTerms){
		
		tazManager = TazDataManager.getInstance(propertyMap);
		int[] tazs = tazManager.getTazs();

		logger.info("*****");
		logger.info("Calculating parking locations");
		logger.info("");
		
		//first create an array list of parking destinations
		ArrayList<Integer> tazArray = new ArrayList<Integer>(0);
		for(int i = 0; i < tazSizeTerms.length; ++i){
			if(tazSizeTerms[i]>0){
				int taz = tazs[i-1];
				tazArray.add(taz);
				logger.info("Added taz "+taz+" to parking destination array");
			}
		}
		
		//convert it to an integer array
		int[] returnArray = new int[tazArray.size()];
		for(int i = 0; i < returnArray.length;++i)
			returnArray[i] = tazArray.get(i);
		
		return returnArray;
	}
	
	/**
	 * Get and return the parking location choice penalty for the destination TAZ, time period, and market segment.
	 * 
	 * @param destinationTaz The destination TAZ
	 * @param timePeriod     THe time period arriving at the lot
	 * @param marketSegment  The market segment
	 * @param debug          A boolean indicating whether to debug the calculation
	 * @return
	 */
	public double getParkingPenalty(int destinationTaz, int timePeriod, int marketSegment, boolean debug){
		
		double parkPenalty = 0f;
				
		if(parkingPenalties==null){
			parkPenalty = calculateParkingPenalty(destinationTaz, timePeriod, marketSegment, debug);
		}else{
			parkPenalty = parkingPenalties[destinationTaz][timePeriod-1][marketSegment];
		}
		
		return parkPenalty;
	}
	
	/**
	 * Calculate and return the parking location choice penalty for the destination TAZ, time period, and market segment.
	 * 
	 * @param destinationTaz The destination TAZ
	 * @param timePeriod     THe time period arriving at the lot
	 * @param marketSegment  The market segment
	 * @param debug          A boolean indicating whether to debug the calculation
	 * @return
	 */
	public double calculateParkingPenalty(int destinationTaz, int timePeriod, int marketSegment, boolean debug){
		double penalty = 0f;
		double totalCapacity = 0f;

		int totalLots = parkingLotDataManager.getNumberOfLots();
		if(totalLots==0){
			logger.fatal("No lots to calculate parking penalty over");
			throw new RuntimeException();
		}
		ArrayList<ParkingLot> parkingLots = parkingLotDataManager.getParkingLots();
			  
		for(ParkingLot lot : parkingLots){
			int lotTaz = lot.getMaz();
			
			// get the total spaces for the market segment
			double totalSpaces = lot.getTotalSpaces();

			if(totalSpaces==0)
				continue;
			
			//skip the lot if no available spaces for the period
			if(simulationModel && lot.getAvailableSpaces(timePeriod)<=0)
				continue;
			
			// get the lot to the destination utility
			double lotToDestinationUtility = getLotToDestinationUtility(lotTaz, destinationTaz,debug);
			
			//get the shadow price for the market segment
			double shadowPrice = lot.getShadowPrice(timePeriod);
			double termTime = lot.getTermTime();
			int informal = lot.getLotType();

			//add the logsum
			penalty += (utilLdCoeff*lotToDestinationUtility + shadowPrice + informalParkConstant[marketSegment]*informal + 4.0*ivtCoeff*termTime)*totalSpaces;
			totalCapacity += totalSpaces;
		}
		penalty = penalty/totalCapacity;
		return penalty;
	}
	
	
	/**
	 * Find the lot based on the parking TAZ and return the shadow price for the person's
	 * market segment and the tour departure period.
	 * 
	 * @param parkingTaz  Parking TAZ
	 * @param departTime   Departure time
	 * @return            The shadow price for parking at the lot.
	 */
	public double getParkingShadowPrice(ParkingLot lot, byte departTime){
		
		return lot.getShadowPrice(departTime);
	}
	
	/**
	 * Get the parking spaces for the lot TAZ
	 * @param parkingTaz  Parking TAZ
	 * @param person      Person with market segment (either a university student or a worker
	 * @param tour        The tour with departure time set
	 * @return            Total spaces at the lot.
	 */
	public double getParkingSpaces(ParkingLot lot, Person person, Tour tour){
			return lot.getTotalSpaces();
	}
	/**
	 * @return the simulationModel
	 */
	public boolean isSimulationModel() {
		return simulationModel;
	}


	/**
	 * @param simulationModel the simulationModel to set
	 */
	public void setSimulationModel(boolean simulationModel) {
		this.simulationModel = simulationModel;
	}
	
	
	public void generateParkingTrips(Household[] households){
		
		logger.info("");
		logger.info("*****************************************");
 		logger.info("Generating trips to/from lots");

		for(Household household: households){
			for(Person person: household.getPersons()){
			    
				if(person==null)
					continue;
				
				ArrayList<Tour> tours = person.getListOfWorkTours();
					
				if(tours==null)
					continue;
				
				generateParkingTrips(household, person, tours);
				
				tours = person.getListOfSchoolTours();
				
				if(tours==null)
					continue;
				
				generateParkingTrips(household, person, tours);
				
			} // end persons

		} //end households
	//	return households;
	}
	
	
	
	public void generateParkingTrips(Household household, Person person, ArrayList<Tour> tours){
		
		for(int i =0; i < tours.size(); ++i){
			
			Tour tour = tours.get(i);
			
			//if not auto tour, continue
			int tourMode = tour.getTourModeChoice() ;
			if(!modelStructure.getTourModeIsSovOrHov(tourMode))
				continue;

			//if not student with tour to campus or worker with tour to campus, continue
			String tourPurpose = tour.getTourPurpose();
			if( !(person.isMajorUniversityStudent() && (tourPurpose.equalsIgnoreCase("University")))
				&& !(person.isMajorUniversityWorker() && (tourPurpose.equalsIgnoreCase("Work"))))
				continue;
			
			//skip tours originating on campus
			if(isParkingDestination(tour.getTourOrigMgra()))
				continue;

			generateOutboundTripsToParkingLot(household,person,tour);
			generateInboundTripsToParkingLot(household,person,tour);
			
		}				
	}


	/**
	 * Generate outbound trips to and from the lot. This method will find the first
	 * parking destination in the tour trip list. It will replace the
	 * trip to the parking destination with a trip to the parking lot, maintaining
	 * the same mode, origin, and time period as the trip to the destination. It will
	 * insert a trip from the lot to the parking destination with the origin equal to the
	 * parking lot taz, with the same time period and purpose as the last trip.
	 * If there are no parking destinations in the tour list, or the parking taz has not
	 * been set in the tour, the method will do nothing.
	 * 
	 * @param tour The tour to modify.
	 */
    public void generateOutboundTripsToParkingLot(Household household, Person person, Tour tour){
    	
    	if(tour.getTourParkMgra()==0)
    		return;
    	
      	Stop[] stops = tour.getOutboundStops();
    	//if no stops, generate an array of stops (really trips), one to parking lot and one to primary destination.
      	if(stops==null){
    		String[] origPurposes = {"Home", "Park"};
    		String[] destPurposes = {"Park",tour.getTourPurpose()};
            int[] stopPurposeIndices = new int[2];
            for(int i = 0; i<stopPurposeIndices.length;++i)
            	if(tour.getTourPurpose().equalsIgnoreCase("Work"))
            		stopPurposeIndices[i]= modelStructure.WORK_STOP_PURPOSE_INDEX;
            	else
            		stopPurposeIndices[i]= modelStructure.UNIV_STOP_PURPOSE_INDEX;
            		
	        tour.createOutboundStops(origPurposes, destPurposes, stopPurposeIndices);
	      	stops = tour.getOutboundStops();
	      	
	      	//stop to lot
	      	Stop stopToLot = stops[0];
	      	stopToLot.setOrig(tour.getTourOrigMgra());
	      	stopToLot.setDest(tour.getTourParkMgra());
	      	stopToLot.setStopPeriod(tour.getTourDepartPeriod());
	      	stopToLot.setPark(tour.getTourParkMgra());
	        stopToLot.setUniversityParkingLot(true);
	        stopToLot.setMode(tour.getTourModeChoice());
	         
	      	//stop from lot to primary destination
	      	Stop stopFromLot = stops[1];
	      	stopFromLot.setOrig(tour.getTourParkMgra());
	      	stopFromLot.setDest(tour.getTourDestMgra());
	      	stopFromLot.setStopPeriod(tour.getTourDepartPeriod());
	      	stopFromLot.setUniversityParkingLot(false);
	      	calculateTripMode(household, person, tour, stopFromLot);
      	}else{
    		String[] origPurposes = new String[stops.length+1];
    		String[] destPurposes = new String[stops.length+1];
    		int[] stopIndices = new int[stops.length+1];
    		int[] stopPeriods = new int[stops.length+1];
    		int[] stopOrigins = new int[stops.length+1];
    		int[] stopDestinations = new int[stops.length+1];
    		int[] stopModes = new int[stops.length+1];
    		int[] stopBoardTaps = new int[stops.length+1];
    		int[] stopAlightTaps = new int[stops.length+1];
    		int[] stopSets = new int[stops.length+1];
      		boolean[] stopUniversityParking = new boolean[stops.length+1];
      		int[] stopLots = new int[stops.length+1];
      		
    		int counter = 0;
    		boolean foundCampusStop = false;
    		for(int i = 0; i<stops.length;++i){
      			
     			Stop existingStop = stops[i];
      			origPurposes[counter] = existingStop.getOrigPurpose();
      			destPurposes[counter] = existingStop.getDestPurpose();
      			stopIndices[counter] = existingStop.getStopPurposeIndex();
      			stopPeriods[counter] = existingStop.getStopPeriod();
     			stopOrigins[counter] = existingStop.getOrig();
      			stopDestinations[counter]= existingStop.getDest();
      		    stopModes[counter] = existingStop.getMode();
      			stopBoardTaps[counter] = existingStop.getBoardTap();
      			stopAlightTaps[counter] = existingStop.getAlightTap();
      			stopSets[counter] = existingStop.getSet();
      			stopUniversityParking[counter] = existingStop.isUniversityParkingLot();
                
      			//is this stop on campus? Note, this is only done once.
      			if(isParkingDestination(existingStop.getDest()) && foundCampusStop==false){
    				foundCampusStop=true;
          			stopDestinations[counter]= tour.getTourParkMgra(); //destination of stop is parking lot
          		    stopUniversityParking[counter] = true;
        	      	stopLots[counter] = tour.getTourParkMgra();
        	      	destPurposes[counter] = "Park";
          		    
          			//insert stop from lot to next destination
          		    ++counter;
        			origPurposes[counter] = "Park";
        			destPurposes[counter] = existingStop.getDestPurpose();
        			stopIndices[counter] = existingStop.getStopPurposeIndex();
          			stopPeriods[counter] = existingStop.getStopPeriod();
         			stopOrigins[counter] = tour.getTourParkMgra(); //origin of stop to next destination is parking lot
          			stopDestinations[counter]= existingStop.getDest();
      			} 	      	 
          		++counter; //keep going with next stop
    		}
	        tour.createOutboundStops(origPurposes, destPurposes, stopIndices);
	      	stops = tour.getOutboundStops();
    		for(int i = 0; i<stops.length;++i){
      			
     			stops[i].setStopPeriod(stopPeriods[i]);
     			stops[i].setOrig(stopOrigins[i]);
      			stops[i].setDest(stopDestinations[i]);
      		    stops[i].setMode(stopModes[i]);
      		    stops[i].setUniversityParkingLot(stopUniversityParking[i]);
      		    
    	      	if(stops[i].getOrigPurpose().equals("Park"))
    	      		calculateTripMode(household, person, tour, stops[i]);
    	      	 
    		}
      	}
      	
    }
    
    public void calculateTripMode(Household household, Person person, Tour tour,Stop stop){
	    
    	int lotTaz = stop.getOrig();
    	int destinationTaz = stop.getDest();
    	
    	// DMUs for this UEC
    	TransitWalkAccessDMU walkDmu = new TransitWalkAccessDMU();
    	// calculate walk-transit exponentiated utility
    	// determine the best transit path, which also stores the best utilities array and the best mode
    	bestPathCalculator.findBestWalkTransitWalkTaps(walkDmu, TransitWalkAccessUEC.MD, lotTaz, destinationTaz, false, logger);
    	double[][] bestTaps = bestPathCalculator.getBestTapPairs(walkDmu, null, bestPathCalculator.WTW, lotTaz, destinationTaz, TransitWalkAccessUEC.MD, household.getDebugChoiceModels(), logger);
    	
    	// sum the exponentiated utilities over modes
    	double opWTExpUtility = bestPathCalculator.getSumExpUtilities();

    	double lotToDestinationTransitExpUtility = Math.exp(transitConstant) * opWTExpUtility;
		double lotToDestinationWalkExpUtility = ntUtilities.getNMotorExpUtility(lotTaz,destinationTaz, ntUtilities.OFFPEAK_PERIOD_INDEX);
	
		//probability of transit
		double lotToDestinationTransitProbability = lotToDestinationTransitExpUtility/(lotToDestinationTransitExpUtility+lotToDestinationWalkExpUtility);
		
		//draw uniform random number
		long seed = household.getSeed() + randomOffset + 23 * ((int) tour.getHhId());
		random.setSeed(seed);
		float rn = (float)random.nextDouble();

		if(rn<lotToDestinationTransitProbability){ //chose transit!
			
			stop.setMode(modelStructure.getWalkTransitTripMode() );
        	int pathindex = logsumHelper.chooseTripPath(rn, bestTaps, household.getDebugChoiceModels(), logger);
        	
        	stop.setBoardTap( (int)bestTaps[pathindex][0] );
        	stop.setAlightTap( (int)bestTaps[pathindex][1] );
        	stop.setSet( (int)bestTaps[pathindex][2] );
		}
		else
			stop.setMode(modelStructure.getWalkTripMode());
    	
    	
    }
	/**
	 * Generate inbound trips to and from the lot. This method will find the last
	 * parking destination in the tour trip list. It will replace the
	 * trip from the parking destination with a trip to the parking lot, maintaining
	 * the same origin, and time period as the trip from the destination. It will
	 * insert a trip from the lot to the next destination with the origin equal to the
	 * parking lot taz, with the same time period and purpose as the last trip.
	 * If there are no parking destinations in the tour list, or the parking taz has not
	 * been set in the tour, the method will do nothing.
	 * 
	 * @param tour The tour to modify.
	 */
    public void generateInboundTripsToParkingLot(Household household, Person person, Tour tour){
    	
       	if(tour.getTourParkMgra()==0)
    		return;
    	
      	Stop[] stops = tour.getInboundStops();
    	//if no stops, generate an array of stops (really trips), one to parking lot and one to tour origin
      	if(stops==null){
    		String[] origPurposes = {tour.getTourPurpose(),"Home"};
    		String[] destPurposes = {tour.getTourPurpose(),tour.getTourPurpose()};
            int[] stopPurposeIndices = new int[2];
            for(int i = 0; i<stopPurposeIndices.length;++i)
            	if(tour.getTourPurpose().equalsIgnoreCase("Work"))
            		stopPurposeIndices[i]= modelStructure.WORK_STOP_PURPOSE_INDEX;
            	else
            		stopPurposeIndices[i]= modelStructure.UNIV_STOP_PURPOSE_INDEX;
            		
	        tour.createInboundStops(origPurposes, destPurposes, stopPurposeIndices);
	      	stops = tour.getInboundStops();
	      	
	      	//stop to lot
	      	Stop stopToLot = stops[0];
	      	stopToLot.setOrig(tour.getTourDestMgra());
	      	stopToLot.setDest(tour.getTourParkMgra());
	      	stopToLot.setStopPeriod(tour.getTourArrivePeriod());
	        stopToLot.setUniversityParkingLot(true);
	        stopToLot.setPark(tour.getTourParkMgra());
	        stopToLot.setDestPurpose("Park");
	        calculateTripMode(household, person, tour, stopToLot);
	         
	      	//stop from lot to primary destination
	      	Stop stopFromLot = stops[1];
	      	stopFromLot.setOrig(tour.getTourParkMgra());
	      	stopFromLot.setDest(tour.getTourOrigMgra());
	      	stopFromLot.setOrigPurpose("Park");
	      	stopFromLot.setStopPeriod(tour.getTourArrivePeriod());
	      	stopFromLot.setUniversityParkingLot(false);
	      	stopFromLot.setMode(tour.getTourModeChoice());
      	}else{
    		String[] origPurposes = new String[stops.length+1];
    		String[] destPurposes = new String[stops.length+1];
    		int[] stopIndices = new int[stops.length+1];
    		int[] stopPeriods = new int[stops.length+1];
    		int[] stopOrigins = new int[stops.length+1];
    		int[] stopDestinations = new int[stops.length+1];
    		int[] stopModes = new int[stops.length+1];
    		int[] stopBoardTaps = new int[stops.length+1];
    		int[] stopAlightTaps = new int[stops.length+1];
    		int[] stopSets = new int[stops.length+1];
      		boolean[] stopUniversityParking = new boolean[stops.length+1];
      		
    		int counter = 0;
    		boolean foundCampusStop = false;
    		for(int i = 0; i<stops.length;++i){
      			
     			Stop existingStop = stops[i];
      			origPurposes[counter] = existingStop.getOrigPurpose();
      			destPurposes[counter] = existingStop.getDestPurpose();
      			stopIndices[counter] = existingStop.getStopPurposeIndex();
      			stopPeriods[counter] = existingStop.getStopPeriod();
     			stopOrigins[counter] = existingStop.getOrig();
      			stopDestinations[counter]= existingStop.getDest();
      		    stopModes[counter] = existingStop.getMode();
      			stopBoardTaps[counter] = existingStop.getBoardTap();
      			stopAlightTaps[counter] = existingStop.getAlightTap();
      			stopSets[counter] = existingStop.getSet();
      			stopUniversityParking[counter] = existingStop.isUniversityParkingLot();
                
      			//is this stop on campus? Note, this is only done once.
      			if(isParkingDestination(existingStop.getOrig()) && foundCampusStop==false){
    				foundCampusStop=true;
          			stopDestinations[counter]= tour.getTourParkMgra(); //destination of stop is parking lot
          		    stopUniversityParking[counter] = true;
          		    destPurposes[counter] = "Park";
          		    
          			//insert stop from lot to next destination
          		    ++counter;
        			origPurposes[counter] = "Park";
        			destPurposes[counter] = existingStop.getDestPurpose();
        			stopIndices[counter] = existingStop.getStopPurposeIndex();
          			stopPeriods[counter] = existingStop.getStopPeriod();
          			stopModes[counter] = existingStop.getMode();
         			stopOrigins[counter] = tour.getTourParkMgra(); //origin of stop to next destination is parking lot
          			stopBoardTaps[counter] = existingStop.getBoardTap();
          			stopAlightTaps[counter] = existingStop.getAlightTap();
          			stopSets[counter] = existingStop.getSet();
          			stopDestinations[counter]= existingStop.getDest();
      			} 	      	 
          		++counter; //keep going with next stop
    		}
	        tour.createInboundStops(origPurposes, destPurposes, stopIndices);
	      	stops = tour.getInboundStops();
    		for(int i = 0; i<stops.length;++i){
      			
     			stops[i].setStopPeriod(stopPeriods[i]);
     			stops[i].setOrig(stopOrigins[i]);
      			stops[i].setDest(stopDestinations[i]);
      		    stops[i].setMode(stopModes[i]);
      		    stops[i].setBoardTap(stopBoardTaps[i]);
      		    stops[i].setAlightTap(stopAlightTaps[i]);
      		    stops[i].setSet(stopSets[i]);
      		    stops[i].setUniversityParkingLot(stopUniversityParking[i]);
      		    
    	      	if(stops[i].getDestPurpose().equals("Park"))
    	      		calculateTripMode(household, person, tour, stops[i]);
    	      	 
    		}
      	}
 
    }

    /**
     * Check to see if TAZ is a parking destination; if so return true else false. Searches the parkingDestinations 
     * array for the TAZ.
     * 
     * @param taz The zone to check
     * @return True if a parking destination, else false.
     */
    public boolean isParkingDestination(int taz){
    	
    	for(int i = 0; i < parkingDestinations.size();++i){
    		if(taz == parkingDestinations.get(i))
    			return true;
    	}
    	return false;
    		
    }
    
    
	/**
	 * Simulate parking location choice for on-campus auto tours. This method is clock-based; it runs through
	 * the tour list in order of arrivals on campus, models the parking location choice, and tracks lots as they
	 * fill up
	 * 
	 * @param households
	 */
	public void simulateParkingChoice(Household[] households){
		
		logger.info("");
		logger.info("*****************************************");
 		logger.info("Simulating parking location choice");

 		//make all spaces available, just in case
        String lotFile =  PropertyMap.getStringValueFromPropertyMap(propertyMap, PROPERTIES_LOTFILE);
        parkingLotDataManager.getInstance(lotFile, periods);
	 	
        for(int period = 1; period <=periods;++period){
	 		totalDemand=0;
			for(Household household: households)
				for(Person person: household.getPersons()){
					
					if(person==null)
						continue;
					
					ArrayList<Tour> tours = null;
					
					if(person.getNumWorkTours()>0){
						tours = person.getListOfWorkTours();
						simulateParkingChoice(household, person, tours, period);
					}
					
					if(person.getNumSchoolTours()>0){
						tours = person.getListOfSchoolTours();
						simulateParkingChoice(household, person, tours, period);
					}
					
				} // end households/persons
				logger.info("...Arrival period "+period+", parking demand "+totalDemand);

			} //end periods
	}
	
	public void simulateParkingChoice(Household household, Person person, ArrayList<Tour> tours, int period){
		for(Tour tour: tours){
			
			int departPeriod = tour.getTourDepartPeriod();
			
			//if not in departure period, continue
			if(departPeriod!=period)
				continue;
			
			//if not auto tour, continue
			int tourMode = tour.getTourModeChoice() ;
			if(!modelStructure.getTourModeIsSovOrHov(tourMode))
				continue;

			//if not student with tour to campus or worker with tour to campus, continue
			String tourPurpose = tour.getTourPurpose();
			if( !(person.isMajorUniversityStudent() && (tourPurpose.equalsIgnoreCase("University")))
				&& !(person.isMajorUniversityWorker() && (tourPurpose.equalsIgnoreCase("Work"))))
				continue;
			
			//if tour originates on campus, skip
			if(isParkingDestination(tour.getTourOrigMgra()))
					continue;

			//calculate the parking zone and set in the tour object
			ParkingLot lotChosen = chooseLotZone(household, person, tour);
			if(lotChosen == null){
				logger.warn("Null returned for parking lot choice for household: "+household.getHhId()
			      +" person "+person.getPersonNum()+" tour "+tour.getTourId()+ " departing in period "+tour.getTourDepartPeriod());
				logger.warn("Setting lot taz to primary destination zone and space type to max space type");
				tour.setTourParkMgra(tour.getTourDestMgra());
				tour.setTourParkSpaceType(maxSpaceType);
			}else{
				tour.setTourParkMgra(lotChosen.getMaz());
				tour.setTourParkSpaceType(lotChosen.getSpaceType());
			}

			//decrease the availability of parking in the lot for the tour duration
			float occupancy = 1.0f;
			if(modelStructure.getTourModeIsS2(tourMode))
				occupancy = 2.0f;
			else if (modelStructure.getTourModeIsS3(tourMode))
				occupancy=occupancyThreePlus;
			 
			float expansionFactor = 1.0f/sampleRate;
			float demand = expansionFactor/occupancy; 
		 	totalDemand += demand;
			int arrivePeriod = tour.getTourArrivePeriod();
			if(lotChosen!=null)
				lotChosen.decreaseAvailableSpaces(departPeriod, arrivePeriod, demand);
		} //end tours
	}
	
	/**
	 * Write unmet demand for parking to a file as specified in property PROPERTIES_UNMETDEMANDFILE.
	 * 
	 */
	public void writeUnmetDemand(){
	
		String fileName = PropertyMap.getStringValueFromPropertyMap(propertyMap, PROPERTIES_UNMETDEMANDFILE);
		PrintWriter writer = null;
		try {
			writer = new PrintWriter(
	                    new BufferedWriter(
	                            new FileWriter(fileName)));
	    } catch (IOException e) {
	    	logger.fatal("Could not open file " + fileName + " for writing\n");
	    	throw new RuntimeException();
	    }

		String line = "parkingSegment";
		
		for(int period =0; period< periods;++period)
			line = line + ",period_" + (period+1);

		writer.write(line+"\n");
		
		for(int parkingSegment = 0; parkingSegment<PARKING_SEGMENTS;++parkingSegment){
			line = new Integer(parkingSegment).toString();
			
			for(int period =0; period< periods;++period)
				line = line + ","+unmetDemand[parkingSegment][period];

			writer.write(line+"\n");
			writer.flush();

		}

		writer.close();
	}
	/**
	 * @return the maxSpaceType
	 */
	public byte getMaxSpaceType() {
		return maxSpaceType;
	}

	
    public String formFileName(String originalFileName, int iteration)
    {
        int lastDot = originalFileName.lastIndexOf('.');

        String returnString = "";
        if (lastDot > 0)
        {
            String base = originalFileName.substring(0, lastDot);
            String ext = originalFileName.substring(lastDot);
            returnString = String.format("%s_%d%s", base, iteration, ext);
        } else
        {
            returnString = String.format("%s_%d.csv", originalFileName, iteration);
        }

        logger.info("writing " + originalFileName + " file to " + returnString);

        return returnString;
    }


	
}
