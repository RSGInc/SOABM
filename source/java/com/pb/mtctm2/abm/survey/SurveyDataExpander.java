package com.pb.mtctm2.abm.survey;

import org.apache.log4j.Logger;

import com.pb.common.matrix.NDimensionalMatrixBalancerDouble;
import com.pb.common.matrix.NDimensionalMatrixDouble;

public class SurveyDataExpander {

	String[] counties = {"Jackson", "Josephine"};
	
	//arrays are jackson, josephine
	private double[][] sizeControls= {
			{22327,30597,11683,9275,6510},
			{8281,11729,4014,2858,2276}};
			 
	private double[][] workerControls= {
			{27805,29378,20263,2946},
			{12623,9348,6364,823}};

	private double[][] incomeControls= {
			{22696,23042,15802,8812,10040},
			{9539,8856,5108,2918,2737}};
	
	private double[][] autoControls = {
			{6191,25427,30695,11842,6237},
			{2395,9746,10498,4473,2046}	};
	
	private NDimensionalMatrixDouble[] seedMatrix;
	
	private Logger logger =  Logger.getLogger(SurveyDataExpander.class);;
	
	/**
	 * Default constructor
	 */
	public void SurveyDataExpander(){};
	
	/**
	 * Read seed matrices from files
	 */
	public void readSeedMatrices(){

		logger.info("Initializing and reading seed matrices");
		seedMatrix = new NDimensionalMatrixDouble[2];
		for(int c = 0; c< counties.length;++c)
			seedMatrix[c] = new NDimensionalMatrixDouble();
		
		seedMatrix[0].readMatrixFromTextFile("c://projects//Oregon_DOT//2013_Flex_Services//WOC07//data//reexpansion//seedDataJacksonCounty.csv");
		seedMatrix[1].readMatrixFromTextFile("c://projects//Oregon_DOT//2013_Flex_Services//WOC07//data//reexpansion//seedDataJosephineCounty.csv");
		logger.info("Done initializing and reading seed matrices");
	}
	
	/**
	 * Balance survey households in each county to marginals
	 */
	public void balance(){
	
		logger.info("Balancing matrices");
	    
		for(int c = 0; c < counties.length;++c){
	    
			logger.info("\nCreating NDimensionalMatrixBalancer for "+counties[c]+" county");

			int[] shape ={sizeControls[c].length,workerControls[c].length,incomeControls[c].length,autoControls[c].length};
	    
			NDimensionalMatrixDouble matrix4d=new NDimensionalMatrixDouble("matrix3d",4,shape);
	        
			NDimensionalMatrixBalancerDouble mb = new NDimensionalMatrixBalancerDouble();
			mb.setTrace(true);
			mb.setSeed(seedMatrix[c]);
			mb.setTarget(sizeControls[c],0);
			mb.setTarget(workerControls[c],1);
			mb.setTarget(incomeControls[c],2);
			mb.setTarget(autoControls[c],3);

			logger.info("Balancing matrix");
			mb.balance();

			//get and print the balanced matrix
			NDimensionalMatrixDouble mbBalanced = mb.getBalancedMatrix();
			mbBalanced.printMatrixDelimited(" ");
		}
	}
	public static void main(String[] args) {

		SurveyDataExpander expander = new SurveyDataExpander();
		expander.readSeedMatrices();
		expander.balance();

	}

}
