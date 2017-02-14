package com.pb.mtctm2.abm.ctramp;

import java.io.Serializable;
import java.util.HashMap;

import org.apache.log4j.Logger;

import com.pb.common.calculator.IndexValues;
import com.pb.common.calculator.VariableTable;

public class MajorUniversityStudentDestChoiceDMU implements Serializable, VariableTable
{
	
	protected transient Logger logger = Logger.getLogger(MajorUniversityStudentDestChoiceModel.class);
	   
	private HashMap<String, Integer> methodIndexMap;
	private IndexValues              dmuIndex;
	
	private double[] loggedSizeTerms; //by maz

	 	
	public MajorUniversityStudentDestChoiceDMU(){
		
        setupMethodIndexMap();
        dmuIndex = new IndexValues();
 
	}

	  /**
     * Set this index values for this tour mode choice DMU object.
     * 
     * @param hhIndex is the DMU household index
     * @param zoneIndex is the DMU zone index
     * @param origIndex is the DMU origin index
     * @param destIndex is the DMU destination index
     */
    public void setDmuIndexValues(int hhIndex, int zoneIndex, int origIndex, int destIndex, boolean debug)
    {
        dmuIndex.setHHIndex(hhIndex);
        dmuIndex.setZoneIndex(zoneIndex);
        dmuIndex.setOriginZone(origIndex);
        dmuIndex.setDestZone(destIndex);

        dmuIndex.setDebug(false);
        dmuIndex.setDebugLabel("");
        if (debug)
        {
            dmuIndex.setDebug(true);
            dmuIndex.setDebugLabel("Debug DC UEC");
        }

    }
	public IndexValues getDmuIndexValues()
    {
        return dmuIndex;
    }
	
	public double getSizeTerm(int alt){
		
		return loggedSizeTerms[alt];
	}

	public double[] getLoggedSizeTerms() {
		return loggedSizeTerms;
	}

	public void setLoggedSizeTerms(double[] loggedSizeTerms) {
		this.loggedSizeTerms = loggedSizeTerms;
	}

	private void setupMethodIndexMap()
    {
        methodIndexMap = new HashMap<String, Integer>();
        methodIndexMap.put( "getSizeTerm", 1 );
         
    }

    public double getValueForIndex(int variableIndex, int arrayIndex)
    {

        double returnValue = -1;

        switch (variableIndex)
        {
        case 1:
            returnValue = getSizeTerm(arrayIndex);
            break;

        default:
            logger.error("method number = " + variableIndex + " not found");
            throw new RuntimeException("method number = " + variableIndex + " not found");
       }

        return returnValue;

    }

  
    public int getIndexValue(String variableName)
    {
        return methodIndexMap.get(variableName);
    }

    public int getAssignmentIndexValue(String variableName)
    {
        throw new UnsupportedOperationException();
    }

    public double getValueForIndex(int variableIndex)
    {
        throw new UnsupportedOperationException();
    }

    public void setValue(String variableName, double variableValue)
    {
        throw new UnsupportedOperationException();
    }

    public void setValue(int variableIndex, double variableValue)
    {
        throw new UnsupportedOperationException();
    }

	
}
