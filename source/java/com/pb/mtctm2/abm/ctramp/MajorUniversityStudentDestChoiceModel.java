package com.pb.mtctm2.abm.ctramp;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;

import org.apache.log4j.Logger;

import com.pb.common.calculator.IndexValues;
import com.pb.common.calculator.VariableTable;
import com.pb.common.datafile.TableDataSet;
import com.pb.common.math.MersenneTwister;
import com.pb.common.newmodel.UtilityExpressionCalculator;

/**
 * A class for university tour destination choice for major university students. This will replace the university
 * campus location with an actual on-campus location for the tour.
 * 
 * @author joel.freedman
 *
 */
public class MajorUniversityStudentDestChoiceModel {
	
	
	private double[] loggedSizeTerms;
    private MajorUniversityStudentDestChoiceDMU decisionMaker;
	private transient Logger logger  = Logger.getLogger(MajorUniversityStudentDestChoiceModel.class);
	
	
 	private static final String UEC_FILENAME_KEY = "majorUniversityStudent.tour.destination.uec.filename";
	private static final String UEC_DATA_SHEET_KEY = "majorUniversityStudent.tour.destination.data.sheet";
	private static final String UEC_MODEL_SHEET_KEY = "majorUniversityStudent.tour.destination.model.sheet";
	private static final String UEC_SIZE_SHEET_KEY = "majorUniversityStudent.tour.destination.size.sheet";
	private static final String PROPERTIES_MODEL_OFFSET   =    "majorUniversityStudent.tour.destination.RNG.offset";

	private long randomOffset = 112111;
	private MersenneTwister random;
	private MgraDataManager mgraDataManager;
	private ChoiceModelApplication choiceModel;
	private UtilityExpressionCalculator sizeTermUEC;
    private TableDataSet alternatives;
    private ArrayList<Integer> universityMazs;

    
    /**
	 * Default constructor.
     * 
     * @param propertyMap
     * @param mgraDataManager
     */
    public MajorUniversityStudentDestChoiceModel(HashMap<String, String> propertyMap, MgraDataManager mgraDataManager){
		
    	String uecPath = propertyMap.get(CtrampApplication.PROPERTIES_UEC_PATH);
        
    	//1. size terms
        String sizeUecFile = uecPath + propertyMap.get(UEC_FILENAME_KEY);
        int dataPage = Util.getIntegerValueFromPropertyMap(propertyMap, UEC_DATA_SHEET_KEY);
        int sizePage = Util.getIntegerValueFromPropertyMap(propertyMap, UEC_SIZE_SHEET_KEY);
        int modelPage = Util.getIntegerValueFromPropertyMap(propertyMap, UEC_MODEL_SHEET_KEY);
 
        decisionMaker = new MajorUniversityStudentDestChoiceDMU();

        // create the choice model object for the dc model and also get the alternatives dataset in order to set the destination correctly.
        choiceModel = new ChoiceModelApplication(sizeUecFile, modelPage, dataPage, propertyMap,
                (VariableTable) decisionMaker);
        UtilityExpressionCalculator choiceModelUEC = choiceModel.getUEC();
        alternatives = choiceModelUEC.getAlternativeData();
        
        sizeTermUEC = new UtilityExpressionCalculator(new File(sizeUecFile),sizePage,dataPage,propertyMap, (VariableTable) decisionMaker);
        
        random = new MersenneTwister();
        randomOffset = Util.getIntegerValueFromPropertyMap(propertyMap, PROPERTIES_MODEL_OFFSET);
        
        this.mgraDataManager = mgraDataManager;
        calculateSizeTerms();
	}


	/**
     * Calculate size terms for all MAZs, log them, and store them in the DMU.
	 */
	public void calculateSizeTerms(){
		
		logger.info("Calculating size terms for major university student destination choice");
		ArrayList<Integer> mazs = mgraDataManager.getMgras();
		int maxMaz = mgraDataManager.getMaxMgra();
		
		loggedSizeTerms = new double[maxMaz+1];
		universityMazs = new ArrayList<Integer>();
       	
		//iterate through MAZs, solve for size
		for(int maz : mazs){
			
			decisionMaker.setDmuIndexValues(1, maz, maz, maz, false);
			IndexValues iValues = decisionMaker.getDmuIndexValues();
			double utilities[] = sizeTermUEC.solve(iValues,decisionMaker,null);
			
			//only one size term
			if(utilities[0] > 0){
				loggedSizeTerms[maz] = Math.log(utilities[0]);
				universityMazs.add(maz);
			}
		}
	       
		decisionMaker.setLoggedSizeTerms(loggedSizeTerms);
		
		logger.info("Finished calculating size terms for major university student destination choice");
		
	}
	
	public ArrayList getUniversityMazs() {
		return universityMazs;
	}


	/**
	 * Choose university tour destinations for all major university students university tours in household.
	 * 
	 * @param household
	 */
	public void chooseDestination(Household household){
		
		Person[] persons = household.getPersons();
		for(int i = 1; i< persons.length;++i){
			
			Person p = persons[i];
			
			if(p.getListOfSchoolTours()==null)
				continue;
			ArrayList<Tour> tours = p.getListOfSchoolTours();
			
			if(tours.size()==0)
				continue;
			
			for(Tour t : tours){
				
				if(t==null)
					continue;

				if(p.isMajorUniversityStudent() && (t.getTourPrimaryPurposeIndex()==ModelStructure.UNIVERSITY_PRIMARY_PURPOSE_INDEX))
					chooseDestination(household, p, t);

			}
		}
	}
	
	
  	/**
	 * Choose a destination MAZ for the tour.
	 * 
	 * @param household
	 * @param person
	 * @param tour
	 */
	public void chooseDestination(Household household, Person person, Tour tour){
		

		//return if not major university student or purpose not university tour
		if(!person.isMajorUniversityStudent() || (tour.getTourPrimaryPurposeIndex()!=ModelStructure.UNIVERSITY_PRIMARY_PURPOSE_INDEX))
			return;
		
        if(household.getDebugChoiceModels()){
        	logger.info("***");
        	logger.info("Choosing destination alternative for major university student university tour");
        	tour.logEntireTourObject(logger);
            
          }
        
        int originTaz = mgraDataManager.getTaz(tour.getTourOrigMgra());
        
        decisionMaker.setDmuIndexValues(1, originTaz, originTaz, 1, household.getDebugChoiceModels());
        choiceModel.computeUtilities(decisionMaker, decisionMaker.getDmuIndexValues());
		
        if(household.getDebugChoiceModels()){
        	choiceModel.logUECResults(logger, "Major university tour destination model");
        }
       
        random.setSeed(household.getSeed() + randomOffset + 23 * person.getPersonNum() + 2942* ((int) tour.getTourId()) );
        
        double rn = random.nextDouble();
        
      	int alt = choiceModel.getChoiceResult(rn);
      	
      	int primaryDestination = (int) alternatives.getValueAt(alt, "mgra");
      	
     	if(household.getDebugChoiceModels()){
      		logger.info("Chose destination MAZ "+primaryDestination+ " with random number "+rn);
      	}
      	
      	tour.setTourDestMgra(primaryDestination);
	}
	
}
